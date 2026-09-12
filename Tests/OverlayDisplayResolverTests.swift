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

extension OverlayDisplayResolverTests {
    @Test("selects either of two ordinary monitors by persistent identifier")
    func selectsSpecificFlatDisplay() {
        let displays = [
            DisplayDescriptor(id: 10, hasNotch: false, isBuiltIn: false, persistentID: "monitor-a"),
            DisplayDescriptor(id: 20, hasNotch: false, isBuiltIn: false, persistentID: "monitor-b"),
        ]
        for surface in [OverlaySurface.notch, .floatingWidget] {
            #expect(OverlayDisplayResolver.resolveIDs(surface: surface, target: .automatic,
                displays: displays, selectedDisplayID: "monitor-a") == [10])
            #expect(OverlayDisplayResolver.resolveIDs(surface: surface, target: .automatic,
                displays: displays, selectedDisplayID: "monitor-b") == [20])
        }
    }

    @Test("missing selected display falls back and reconnects despite changed numeric ID")
    func reconnectsSelectedDisplay() {
        let primary = DisplayDescriptor(id: 10, hasNotch: false, isBuiltIn: false, persistentID: "a")
        let reconnected = DisplayDescriptor(id: 99, hasNotch: false, isBuiltIn: false, persistentID: "b")
        #expect(OverlayDisplayResolver.resolveIDs(surface: .floatingWidget, target: .automatic,
            displays: [primary], selectedDisplayID: "b") == [10])
        #expect(OverlayDisplayResolver.resolveIDs(surface: .floatingWidget, target: .automatic,
            displays: [reconnected, primary], selectedDisplayID: "b") == [99])
        #expect(OverlayDisplayResolver.resolveIDs(surface: .floatingWidget, target: .automatic,
            displays: [], selectedDisplayID: "b").isEmpty)
    }

    @Test("specific monitor preferences coexist with legacy policies")
    func selectionEncoding() {
        #expect(DisplaySelection.persistentID(from: DisplaySelection.value(for: "monitor-uuid")) == "monitor-uuid")
        for target in NotchDisplayTarget.allCases {
            #expect(DisplaySelection.persistentID(from: target.rawValue) == nil)
        }
        #expect(DisplaySelection.persistentID(from: "display:") == nil)
    }
}
