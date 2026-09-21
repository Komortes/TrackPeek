import Foundation
import ImageIO

actor ArtworkImageLoader {
    static let shared = ArtworkImageLoader()

    struct Key: Hashable, Sendable {
        let url: URL
        let pixels: Int

        init(url: URL, pixelSize: CGFloat) {
            self.url = url
            let size = pixelSize.isFinite ? min(max(pixelSize, 1), 1024) : 1024
            pixels = [64, 128, 256, 512, 1024].first { CGFloat($0) >= size } ?? 1024
        }
    }

    private struct Request {
        let id: UUID
        let task: Task<CGImage?, Never>
        var consumers: Set<UUID>
    }

    private let dataLoader: ArtworkDataLoader
    private let maximumCacheBytes: Int
    private var cache: [Key: CGImage] = [:]
    private var cacheOrder: [Key] = []
    private(set) var cachedByteCount = 0
    private var requests: [Key: Request] = [:]

    init(dataLoader: ArtworkDataLoader = .shared, maximumCacheBytes: Int = 16_000_000) {
        self.dataLoader = dataLoader
        self.maximumCacheBytes = max(0, maximumCacheBytes)
    }

    deinit { for request in requests.values { request.task.cancel() } }

    func image(for url: URL?, pixelSize: CGFloat) async -> CGImage? {
        guard let url, !Task.isCancelled else { return nil }
        let key = Key(url: url, pixelSize: pixelSize)
        if let image = cache[key] {
            cacheOrder.removeAll { $0 == key }
            cacheOrder.append(key)
            return image
        }
        let consumer = UUID()
        if requests[key] == nil {
            let dataLoader = dataLoader
            let task = Task.detached(priority: .utility) { () -> CGImage? in
                do {
                    let data = try await dataLoader.data(for: url)
                    try Task.checkCancellation()
                    let image = autoreleasepool { Self.thumbnail(from: data, pixels: key.pixels) }
                    if image == nil { await dataLoader.discard(data, for: url) }
                    return image
                } catch { return nil }
            }
            requests[key] = Request(id: UUID(), task: task, consumers: [])
        }
        requests[key]?.consumers.insert(consumer)
        guard let request = requests[key] else { return nil }
        return await withTaskCancellationHandler {
            let image = await request.task.value
            if requests[key]?.id == request.id {
                requests[key] = nil
                if let image { store(image, for: key) }
            }
            return Task.isCancelled ? nil : image
        } onCancel: {
            Task { await self.cancel(consumer, for: key, requestID: request.id) }
        }
    }

    private func cancel(_ consumer: UUID, for key: Key, requestID: UUID) {
        guard requests[key]?.id == requestID else { return }
        requests[key]?.consumers.remove(consumer)
        if requests[key]?.consumers.isEmpty == true {
            requests[key]?.task.cancel()
            requests[key] = nil
        }
    }

    private func store(_ image: CGImage, for key: Key) {
        let cost = image.bytesPerRow * image.height
        guard cost <= maximumCacheBytes else { return }
        cache[key] = image
        cacheOrder.append(key)
        cachedByteCount += cost
        while cachedByteCount > maximumCacheBytes || cacheOrder.count > 48 {
            if let evicted = cache.removeValue(forKey: cacheOrder.removeFirst()) {
                cachedByteCount -= evicted.bytesPerRow * evicted.height
            }
        }
    }

    nonisolated static func thumbnail(from data: Data, pixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(max(pixels, 1), 1024),
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    }
}
