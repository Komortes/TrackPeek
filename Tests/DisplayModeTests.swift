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

    @Test("exposes every product mode as working")
    func fallsBackToMenuBar() {
        #expect(DisplayMode.fallback == .menuBar)
        #expect(DisplayMode.allCases.allSatisfy { $0.isAvailable })
    }
}
