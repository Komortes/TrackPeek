import AppKit
import Foundation
import ImageIO

struct ArtworkColor: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    var brightness: Double {
        max(red, green, blue)
    }

    var saturation: Double {
        guard brightness > 0 else { return 0 }
        return (brightness - min(red, green, blue)) / brightness
    }

    func distance(to other: ArtworkColor) -> Double {
        let redDistance = red - other.red
        let greenDistance = green - other.green
        let blueDistance = blue - other.blue
        return sqrt(
            redDistance * redDistance
                + greenDistance * greenDistance
                + blueDistance * blueDistance
        )
    }

    var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// Акцент, гарантированно читаемый на почти чёрной панели: слишком тёмный
    /// цвет обложки подмешивается к белому до минимальной светимости,
    /// сохраняя оттенок.
    var onDarkSurface: ArtworkColor {
        let minimumLuminance = 0.45
        guard luminance < minimumLuminance else { return self }

        let amount = (minimumLuminance - luminance) / max(1 - luminance, 0.001)
        return mixed(with: ArtworkColor(red: 1, green: 1, blue: 1), amount: amount)
    }

    func mixed(with other: ArtworkColor, amount: Double) -> ArtworkColor {
        let amount = min(max(amount, 0), 1)
        return ArtworkColor(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount
        )
    }
}

struct ArtworkPalette: Equatable, Sendable {
    let primary: ArtworkColor
    let secondary: ArtworkColor
    let tertiary: ArtworkColor

    static let fallback = ArtworkPalette(
        primary: ArtworkColor(red: 0.35, green: 0.78, blue: 0.98),
        secondary: ArtworkColor(red: 0.68, green: 0.45, blue: 0.98),
        tertiary: ArtworkColor(red: 0.20, green: 0.92, blue: 0.72)
    )

    var colors: [ArtworkColor] {
        [primary, secondary, tertiary]
    }

    @MainActor
    static var systemAccent: ArtworkPalette {
        let accent = NSColor.controlAccentColor.usingColorSpace(.deviceRGB)
            ?? NSColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1)
        let base = ArtworkColor(
            red: accent.redComponent,
            green: accent.greenComponent,
            blue: accent.blueComponent
        )
        let white = ArtworkColor(red: 1, green: 1, blue: 1)
        let black = ArtworkColor(red: 0, green: 0, blue: 0)

        return ArtworkPalette(
            primary: base,
            secondary: base.mixed(with: white, amount: 0.35),
            tertiary: base.mixed(with: black, amount: 0.25)
        )
    }
}

enum ArtworkPaletteExtractor {
    static func palette(from samples: [ArtworkColor]) -> ArtworkPalette {
        guard !samples.isEmpty else { return .fallback }

        let candidates = samples
            .filter { $0.brightness > 0.07 && $0.brightness < 0.98 }
            .sorted { quality(of: $0) > quality(of: $1) }
        let source = candidates.isEmpty ? samples : candidates
        guard let primary = source.first else { return .fallback }

        var selected = [primary]
        while selected.count < 3 {
            guard let candidate = source
                .filter({ !selected.contains($0) })
                .max(by: {
                    selectionScore($0, against: selected)
                        < selectionScore($1, against: selected)
                }),
                selected.allSatisfy({ candidate.distance(to: $0) > 0.16 })
            else {
                break
            }
            selected.append(candidate)
        }

        let accents = ArtworkPalette.fallback.colors
        while selected.count < 3 {
            let accent = accents[selected.count]
            var variant = primary.mixed(with: accent, amount: 0.62)
            if selected.contains(variant) {
                variant = accent
            }
            selected.append(variant)
        }

        return ArtworkPalette(
            primary: selected[0],
            secondary: selected[1],
            tertiary: selected[2]
        )
    }

    private static func quality(of color: ArtworkColor) -> Double {
        color.saturation * 0.72 + color.brightness * 0.28
    }

    private static func selectionScore(
        _ color: ArtworkColor,
        against selected: [ArtworkColor]
    ) -> Double {
        let minimumDistance = selected.map { color.distance(to: $0) }.min() ?? 0
        return quality(of: color) + minimumDistance * 0.85
    }
}

actor ArtworkPaletteLoader {
    static let shared = ArtworkPaletteLoader()

    private let maximumCacheEntries = 48
    private var cache: [URL: ArtworkPalette] = [:]
    private var cacheOrder: [URL] = []
    private var inFlight: [URL: Task<ArtworkPalette?, Never>] = [:]
    private let loadData: @Sendable (URL) async throws -> Data
    static let maximumDataBytes = 8_000_000

    init(loadData: @escaping @Sendable (URL) async throws -> Data = ArtworkPaletteLoader.readData) {
        self.loadData = loadData
    }

    deinit { for task in inFlight.values { task.cancel() } }

    func palette(for url: URL?) async -> ArtworkPalette {
        guard
            let url,
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http" || scheme == "file"
        else {
            return .fallback
        }
        if let cached = cache[url] {
            cacheOrder.removeAll { $0 == url }
            cacheOrder.append(url)
            return cached
        }

        if let task = inFlight[url] { return await task.value ?? .fallback }
        guard inFlight.count < 4, !Task.isCancelled else { return .fallback }
        let loadData = loadData
        let task = Task.detached(priority: .utility) { () -> ArtworkPalette? in
            do {
                let data = try await loadData(url)
                try Task.checkCancellation()
                guard data.count <= Self.maximumDataBytes else { return nil }
                return autoreleasepool { Self.extractPalette(from: data) }
            } catch { return nil }
        }
        inFlight[url] = task
        let palette = await task.value
        inFlight[url] = nil
        if let palette { store(palette, for: url) }
        return palette ?? .fallback
    }

    nonisolated static func readData(_ url: URL) async throws -> Data {
        if url.isFileURL {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: maximumDataBytes + 1) ?? Data()
            guard data.count <= maximumDataBytes else { throw URLError(.dataLengthExceedsMaximum) }
            return data
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .returnCacheDataElseLoad
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        guard response.expectedContentLength <= maximumDataBytes else {
            throw URLError(.dataLengthExceedsMaximum)
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumDataBytes else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        return data
    }

    private func store(_ palette: ArtworkPalette, for url: URL) {
        cache[url] = palette
        cacheOrder.removeAll { $0 == url }
        cacheOrder.append(url)

        while cacheOrder.count > maximumCacheEntries {
            cache.removeValue(forKey: cacheOrder.removeFirst())
        }
    }

    nonisolated static func thumbnail(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    }

    private nonisolated static func extractPalette(from data: Data) -> ArtworkPalette? {
        guard let image = thumbnail(from: data) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: image)

        let columns = 10
        let rows = 10
        let width = max(bitmap.pixelsWide, 1)
        let height = max(bitmap.pixelsHigh, 1)
        var samples: [ArtworkColor] = []
        samples.reserveCapacity(columns * rows)

        for row in 0 ..< rows {
            for column in 0 ..< columns {
                let x = min((column * width + width / 2) / columns, width - 1)
                let y = min((row * height + height / 2) / rows, height - 1)
                guard
                    let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
                else {
                    continue
                }
                samples.append(
                    ArtworkColor(
                        red: color.redComponent,
                        green: color.greenComponent,
                        blue: color.blueComponent
                    )
                )
            }
        }

        return ArtworkPaletteExtractor.palette(from: samples)
    }
}
