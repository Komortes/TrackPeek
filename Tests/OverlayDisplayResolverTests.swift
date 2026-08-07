import Testing
@testable import TrackPeek

@Suite("Overlay display resolver")
struct OverlayDisplayResolverTests {
    private let builtInNotched = DisplayDescriptor(id: 1, hasNotch: true, isBuiltIn: true)
    private let external = DisplayDescriptor(id: 2, hasNotch: false, isBuiltIn: false)
    private let secondExternal = DisplayDescriptor(id: 3, hasNotch: false, isBuiltIn: false)

    @Test("automatic notch goes only to the physically notched display")
    func automaticNotchPrefersNotchedDisplay() {
        #expect(
            OverlayDisplayResolver.resolveIDs(
                surface: .notch, target: .automatic,
                displays: [external, builtInNotched]
            ) == [1]
        )
        // Нет выреза — нет чёлки: виртуальную чёлку не симулируем (§20.1).
        #expect(
            OverlayDisplayResolver.resolveIDs(
                surface: .notch, target: .automatic,
                displays: [external, secondExternal]
            ) == []
        )
    }

    @Test("automatic widget prefers the first external display")
    func automaticWidgetPrefersExternal() {
        #expect(
            OverlayDisplayResolver.resolveIDs(
                surface: .floatingWidget, target: .automatic,
                displays: [builtInNotched, external, secondExternal]
            ) == [2]
        )
        // Внешний отключили — виджет переезжает на встроенный, а не виснет
        // на координатах пропавшего экрана.
        #expect(
            OverlayDisplayResolver.resolveIDs(
                surface: .floatingWidget, target: .automatic,
                displays: [builtInNotched]
            ) == [1]
        )
    }

    @Test("manual targets keep their existing behavior")
    func manualTargetsUnchanged() {
        let displays = [builtInNotched, external]
        #expect(
            OverlayDisplayResolver.resolveIDs(
                surface: .notch, target: .mainDisplay, displays: displays
            ) == [1]
        )
        #expect(
            OverlayDisplayResolver.resolveIDs(
                surface: .notch, target: .notchedDisplay, displays: [external, builtInNotched]
            ) == [1]
        )
        #expect(
            OverlayDisplayResolver.resolveIDs(
                surface: .floatingWidget, target: .allDisplays, displays: displays
            ) == [1, 2]
        )
    }

    @Test("automatic raw value stays stable")
    func automaticRawValueStable() {
        #expect(NotchDisplayTarget(rawValue: "automatic") == .automatic)
    }
}
