import Testing
import AppKit
@testable import TrackPeek

@Suite("Artwork palette")
struct ArtworkPaletteTests {
    @Test("selects three distinct vivid colors from artwork samples")
    func selectsDistinctVividColors() {
        let red = ArtworkColor(red: 0.92, green: 0.12, blue: 0.18)
        let blue = ArtworkColor(red: 0.12, green: 0.38, blue: 0.96)
        let green = ArtworkColor(red: 0.12, green: 0.82, blue: 0.48)

        let palette = ArtworkPaletteExtractor.palette(
            from: [
                .init(red: 0.03, green: 0.03, blue: 0.04),
                red,
                blue,
                green,
                red,
                blue,
            ]
        )

        #expect(palette.colors.contains(red))
        #expect(palette.colors.contains(blue))
        #expect(palette.colors.contains(green))
        #expect(Set(palette.colors).count == 3)
    }

    @Test("uses a stable fallback when artwork has no samples")
    func usesStableFallback() {
        #expect(ArtworkPaletteExtractor.palette(from: []) == .fallback)
    }

    @Test("builds usable contrast from monochrome artwork")
    func buildsContrastFromMonochromeArtwork() {
        let gray = ArtworkColor(red: 0.34, green: 0.34, blue: 0.34)
        let palette = ArtworkPaletteExtractor.palette(from: [gray, gray, gray])

        #expect(Set(palette.colors).count == 3)
        #expect(palette.colors.allSatisfy { $0.brightness > 0.2 })
    }
}

@Suite("Dark surface accent contrast")
struct DarkSurfaceContrastTests {
    @Test("brightens too-dark artwork accents to a readable minimum")
    func brightensDarkAccents() {
        let dark = ArtworkColor(red: 0.1, green: 0.05, blue: 0.12)
        #expect(dark.onDarkSurface.luminance >= 0.44)
    }

    @Test("keeps already-bright accents untouched")
    func keepsBrightAccents() {
        let bright = ArtworkColor(red: 0.4, green: 0.8, blue: 0.9)
        #expect(bright.onDarkSurface == bright)
    }
}


@MainActor
@Suite("Artwork loading limits")
struct ArtworkLoadingTests {
    static func imageData() -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2048,
            pixelsHigh: 2048, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return bitmap.representation(using: .png, properties: [:])!
    }

    @Test("large artwork is downsampled before palette extraction")
    func thumbnailSize() throws {
        let data = Self.imageData()
        let image = try #require(ArtworkPaletteLoader.thumbnail(from: data))
        #expect(image.width <= 64)
        #expect(image.height <= 64)
        #expect(ArtworkPaletteLoader.thumbnail(from: Data("invalid".utf8)) == nil)
    }

    @Test("concurrent requests for one URL share their load")
    func sharesLoad() async {
        let provider = ArtworkDataProvider(data: Self.imageData())
        let loader = ArtworkPaletteLoader { _ in try await provider.load() }
        let url = URL(string: "https://example.com/art.png")!
        await withTaskGroup(of: ArtworkPalette.self) { group in
            for _ in 0..<8 { group.addTask { await loader.palette(for: url) } }
            for await _ in group { }
        }
        #expect(await provider.calls == 1)
        _ = await loader.palette(for: url)
        #expect(await provider.calls == 1)
    }

    @Test("oversized files are rejected before decoding")
    func oversizedFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(count: ArtworkPaletteLoader.maximumDataBytes + 1).write(to: url)
        do {
            _ = try await ArtworkPaletteLoader.readData(url)
            Issue.record("Expected an oversized-file error")
        } catch let error as URLError {
            #expect(error.code == .dataLengthExceedsMaximum)
        }
    }
}

private actor ArtworkDataProvider {
    let data: Data
    var calls = 0
    init(data: Data) { self.data = data }
    func load() async throws -> Data {
        calls += 1
        try await Task.sleep(for: .milliseconds(50))
        return data
    }
}
