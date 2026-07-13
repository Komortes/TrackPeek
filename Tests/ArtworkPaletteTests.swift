import Testing
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
