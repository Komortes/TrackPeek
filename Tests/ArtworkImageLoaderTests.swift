import AppKit
import SwiftUI
import Testing
@testable import TrackPeek

@Suite("Shared artwork pipeline", .timeLimit(.minutes(1)))
struct ArtworkImageLoaderTests {
    @Test("thumbnails respect pixel size and reuse both download and decoded image")
    func sizedImages() async throws {
        let provider = ImageBytesProvider(data: await ArtworkLoadingTests.imageData())
        let dataLoader = ArtworkDataLoader { _ in await provider.load() }
        let loader = ArtworkImageLoader(dataLoader: dataLoader)
        let url = URL(string: "https://example.com/cover")!
        let small = try #require(await loader.image(for: url, pixelSize: 100))
        #expect(small.width == 128)
        let same = try #require(await loader.image(for: url, pixelSize: 120))
        #expect(small === same)
        let large = try #require(await loader.image(for: url, pixelSize: 300))
        #expect(large.width == 512)
        #expect(await provider.calls == 1)
    }

    @Test("card, background and palette share a single download")
    func sharedConsumers() async {
        let provider = ImageBytesProvider(data: await ArtworkLoadingTests.imageData())
        let dataLoader = ArtworkDataLoader { _ in await provider.load() }
        let loader = ArtworkImageLoader(dataLoader: dataLoader)
        let palette = ArtworkPaletteLoader { try await dataLoader.data(for: $0) }
        let url = URL(string: "https://example.com/shared")!
        async let card = loader.image(for: url, pixelSize: 300)
        async let background = loader.image(for: url, pixelSize: 128)
        async let colors = palette.palette(for: url)
        let (image, blur, _) = await (card, background, colors)
        #expect(image != nil)
        #expect(blur != nil)
        #expect(await provider.calls == 1)
    }

    @Test("decoded cache evicts by bytes and keeps recent images")
    func decodedBudget() async throws {
        let provider = ImageBytesProvider(data: await ArtworkLoadingTests.imageData())
        let dataLoader = ArtworkDataLoader { _ in await provider.load() }
        let loader = ArtworkImageLoader(dataLoader: dataLoader, maximumCacheBytes: 100_000)
        let a = URL(string: "https://example.com/a")!
        let b = URL(string: "https://example.com/b")!
        let first = try #require(await loader.image(for: a, pixelSize: 128))
        _ = await loader.image(for: b, pixelSize: 128)
        let reloaded = try #require(await loader.image(for: a, pixelSize: 128))
        #expect(first !== reloaded)
        #expect(await loader.cachedByteCount <= 100_000)
        #expect(await provider.calls == 2) // Encoded bytes can still be reused.
    }

    @Test("encoded cache is bounded and does not store errors")
    func encodedBudget() async throws {
        let provider = ImageBytesProvider(data: Data(repeating: 1, count: 16))
        let loader = ArtworkDataLoader(maximumCacheBytes: 20) { _ in await provider.load() }
        let a = URL(string: "https://example.com/a")!
        let b = URL(string: "https://example.com/b")!
        _ = try await loader.data(for: a)
        _ = try await loader.data(for: b)
        _ = try await loader.data(for: a)
        #expect(await provider.calls == 3)
        #expect(await loader.cachedByteCount == 16)
    }

    @Test("a corrupt successful response is discarded so the next load can recover")
    func retriesCorruptImage() async {
        let provider = RecoveringImageBytes(data: await ArtworkLoadingTests.imageData())
        let dataLoader = ArtworkDataLoader { _ in await provider.load() }
        let loader = ArtworkImageLoader(dataLoader: dataLoader)
        let url = URL(string: "https://example.com/recovered")!
        #expect(await loader.image(for: url, pixelSize: 128) == nil)
        #expect(await loader.image(for: url, pixelSize: 128) != nil)
        #expect(await provider.calls == 2)
    }

    @Test("unsupported URLs and invalid image bytes do not enter the decoded cache")
    func invalidImage() async {
        let provider = ImageBytesProvider(data: Data("bad image".utf8))
        let dataLoader = ArtworkDataLoader { _ in await provider.load() }
        let loader = ArtworkImageLoader(dataLoader: dataLoader)
        #expect(await loader.image(for: URL(string: "ftp://example.com/a"), pixelSize: 64) == nil)
        #expect(await loader.image(for: nil, pixelSize: 64) == nil)
        #expect(await loader.image(for: URL(string: "https://example.com/a"), pixelSize: 64) == nil)
        #expect(await provider.calls == 1)
        #expect(await loader.cachedByteCount == 0)
    }
}

private actor ImageBytesProvider {
    let data: Data
    var calls = 0
    init(data: Data) { self.data = data }
    func load() -> Data {
        calls += 1
        return data
    }
}

@Suite("Artwork request cancellation", .timeLimit(.minutes(1)))
struct ArtworkCancellationTests {
    @Test("canceling one image consumer preserves the other's shared download")
    func preservesSharedDownload() async throws {
        let provider = SuspendedArtworkData()
        let bytes = await ArtworkLoadingTests.imageData()
        let dataLoader = ArtworkDataLoader { try await provider.load($0) }
        let loader = ArtworkImageLoader(dataLoader: dataLoader)
        let url = URL(string: "https://example.com/shared-cancel")!
        let first = Task { await loader.image(for: url, pixelSize: 128) }
        await provider.waitForRequest(url)
        let second = Task { await loader.image(for: url, pixelSize: 128) }
        for _ in 0..<100 { await Task.yield() }
        first.cancel()
        await provider.complete(url, data: bytes)
        #expect(await first.value == nil)
        #expect(await second.value != nil)
        #expect(await provider.count(for: url) == 1)
    }

    @Test("canceling the last consumer releases it even when the provider replies late")
    func cancelledConsumer() async throws {
        let provider = SuspendedArtworkData()
        let loader = ArtworkDataLoader { try await provider.load($0) }
        let url = URL(string: "https://example.com/old")!
        let first = Task { try await loader.data(for: url) }
        await provider.waitForRequest(url)
        first.cancel()
        do {
            _ = try await first.value
            Issue.record("Cancelled consumer received data")
        } catch is CancellationError { }
        // The producer ignores cancellation. Its late bytes must not enter cache.
        await provider.complete(url, data: Data([1]))
        let second = Task { try await loader.data(for: url) }
        await provider.waitForRequest(url, count: 2)
        await provider.complete(url, data: Data([2]))
        #expect(try await second.value == Data([2]))
        #expect(await loader.cachedByteCount == 1)
    }

    @Test("queued cancellation and slow cancellation do not exceed four downloads")
    func downloadLimit() async throws {
        let provider = SuspendedArtworkData()
        let loader = ArtworkDataLoader { try await provider.load($0) }
        let urls = (0..<6).map { URL(string: "https://example.com/\($0)")! }
        var tasks: [Task<Data, Error>] = []
        for url in urls.prefix(4) {
            tasks.append(Task { try await loader.data(for: url) })
            await provider.waitForRequest(url)
        }
        let queued = Task { try await loader.data(for: urls[4]) }
        queued.cancel()
        do {
            _ = try await queued.value
            Issue.record("Expected cancellation")
        } catch is CancellationError { }
        tasks[0].cancel()
        _ = try? await tasks[0].value
        let newest = Task { try await loader.data(for: urls[5]) }
        for _ in 0..<100 { await Task.yield() }
        await provider.complete(urls[0], data: Data([0]))
        await provider.waitForRequest(urls[5])
        for (index, url) in urls.prefix(4).enumerated() where index > 0 {
            await provider.complete(url, data: Data([UInt8(index)]))
            #expect(try await tasks[index].value == Data([UInt8(index)]))
        }
        await provider.complete(urls[5], data: Data([5]))
        #expect(try await newest.value == Data([5]))
        #expect(await provider.maximumActive <= 4)
        #expect(await provider.count(for: urls[4]) == 0)
    }

    @Test("failed downloads are not cached and can succeed on retry")
    func retryFailure() async throws {
        let provider = SuspendedArtworkData()
        let loader = ArtworkDataLoader { try await provider.load($0) }
        let url = URL(string: "https://example.com/retry")!
        let first = Task { try await loader.data(for: url) }
        await provider.waitForRequest(url)
        await provider.fail(url)
        do {
            _ = try await first.value
            Issue.record("Expected network error")
        } catch let error as URLError { #expect(error.code == .notConnectedToInternet) }
        #expect(await loader.cachedByteCount == 0)
        let second = Task { try await loader.data(for: url) }
        await provider.waitForRequest(url, count: 2)
        await provider.complete(url, data: Data([42]))
        #expect(try await second.value == Data([42]))
    }
}

private actor SuspendedArtworkData {
    private var pending: [URL: CheckedContinuation<Data, Error>] = [:]
    private var counts: [URL: Int] = [:]
    private var observers: [URL: (Int, CheckedContinuation<Void, Never>)] = [:]
    private(set) var maximumActive = 0

    func count(for url: URL) -> Int { counts[url, default: 0] }

    func load(_ url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            counts[url, default: 0] += 1
            pending[url] = continuation
            maximumActive = max(maximumActive, pending.count)
            if let (count, waiter) = observers[url], counts[url, default: 0] >= count {
                observers[url] = nil
                waiter.resume()
            }
        }
    }

    func waitForRequest(_ url: URL, count: Int = 1) async {
        if counts[url, default: 0] >= count { return }
        await withCheckedContinuation { observers[url] = (count, $0) }
    }

    func complete(_ url: URL, data: Data) {
        pending.removeValue(forKey: url)?.resume(returning: data)
    }

    func fail(_ url: URL) {
        pending.removeValue(forKey: url)?.resume(throwing: URLError(.notConnectedToInternet))
    }
}

private actor RecoveringImageBytes {
    let data: Data
    var calls = 0
    init(data: Data) { self.data = data }
    func load() -> Data {
        calls += 1
        return calls == 1 ? Data("invalid image".utf8) : data
    }
}

@MainActor
@Suite("Artwork presentation")
struct ArtworkPresentationTests {
    private let small = ArtworkImageLoader.Key(url: URL(string: "https://example.com/a")!, pixelSize: 64)
    private let large = ArtworkImageLoader.Key(url: URL(string: "https://example.com/a")!, pixelSize: 512)
    private let other = ArtworkImageLoader.Key(url: URL(string: "https://example.com/b")!, pixelSize: 64)

    private func image() throws -> CGImage {
        try #require(ArtworkImageLoader.thumbnail(from: ArtworkLoadingTests.imageData(), pixels: 64))
    }

    @Test("resizing keeps the same cover before and during the new request")
    func resizing() throws {
        var state = ArtworkImagePresentation()
        let original = try image()
        let first = state.begin(small)
        state.complete(first, image: original)
        #expect(state.image(for: large) === original)
        let resized = state.begin(large)
        #expect(state.image(for: large) === original)
        let replacement = try image()
        state.complete(resized, image: replacement)
        #expect(state.image(for: large) === replacement)
    }

    @Test("new track cannot display the previous cover even before its task begins")
    func changedTrack() throws {
        var state = ArtworkImagePresentation()
        let first = state.begin(small)
        state.complete(first, image: try image())
        #expect(state.image(for: other) == nil)
        _ = state.begin(other)
        #expect(state.image(for: other) == nil)
        #expect(state.image(for: small) == nil)
    }

    @Test("late success and failure cannot replace newer requests including A B A")
    func lateResults() throws {
        var state = ArtworkImagePresentation()
        let oldA = state.begin(small)
        let oldB = state.begin(other)
        let newA = state.begin(small)
        let current = try image()
        state.complete(newA, image: current)
        state.complete(oldB, image: try image())
        state.complete(oldA, image: nil)
        #expect(state.image(for: small) === current)
        #expect(!state.failed(for: small))
    }

    @Test("failed resize keeps usable pixels and failed new artwork reaches a terminal state")
    func failedLoad() throws {
        var state = ArtworkImagePresentation()
        let first = state.begin(small)
        state.complete(first, image: try image())
        let resized = state.begin(large)
        state.complete(resized, image: nil)
        #expect(state.image(for: large) != nil)
        let changed = state.begin(other)
        state.complete(changed, image: nil)
        #expect(state.image(for: other) == nil)
        #expect(state.failed(for: other))
        #expect(!state.failed(for: small))
    }

    @Test("missing artwork releases the previous image and rejects a late reply")
    func missingArtwork() throws {
        var state = ArtworkImagePresentation()
        let first = state.begin(small)
        state.complete(first, image: try image())
        let pending = state.begin(large)
        _ = state.begin(nil)
        state.complete(pending, image: try image())
        #expect(state.image(for: nil) == nil)
        #expect(state.image(for: small) == nil)
        #expect(!state.failed(for: nil))
    }
}

@MainActor
@Suite("Artwork placeholder layout")
struct ArtworkPlaceholderLayoutTests {
    @Test("renders quiet missing artwork at small and large sizes without changing geometry")
    func placeholderSizes() throws {
        let content = HStack(alignment: .center, spacing: 20) {
            ForEach([16, 24, 32, 64, 100], id: \.self) { size in
                VStack(spacing: 10) {
                    TrackArtworkView(url: nil, size: CGFloat(size), cornerRadius: 4, showsShadow: false)
                    Text("\(size) pt").font(.system(size: 10))
                }
            }
        }
        .padding(20)
        .environment(\.colorScheme, .dark)
        .environment(\.resourceSaving, true)
        .background(Color.black)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width > 600)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("trackpeek-artwork-placeholders.png"))
    }
}
