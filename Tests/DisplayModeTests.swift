import Testing
@testable import TrackPeek

@Suite("Display modes")
struct DisplayModeTests {
    @Test("exposes the three product modes in settings order")
    func exposesThreeModes() {
        #expect(DisplayMode.allCases == [.menuBar, .notch, .floatingWidget])
    }

    @Test("uses stable persisted values")
    func usesStablePersistedValues() {
        #expect(DisplayMode(rawValue: "menuBar") == .menuBar)
        #expect(DisplayMode(rawValue: "notch") == .notch)
        #expect(DisplayMode(rawValue: "floatingWidget") == .floatingWidget)
    }

    @Test("exposes menu bar and notch as working modes")
    func fallsBackToMenuBar() {
        #expect(DisplayMode.fallback == .menuBar)
        #expect(DisplayMode.menuBar.isAvailable)
        #expect(DisplayMode.notch.isAvailable)
        #expect(!DisplayMode.floatingWidget.isAvailable)
    }
}
