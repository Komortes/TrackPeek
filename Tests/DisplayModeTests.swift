import Foundation
import Testing
@testable import TrackPeek

@Suite("Overlay modes")
struct OverlayModeTests {
    @Test("exposes the three overlay options in settings order")
    func exposesThreeModes() {
        #expect(OverlayMode.allCases == [.off, .notch, .floatingWidget])
    }

    @Test("uses stable persisted values and an off fallback")
    func usesStablePersistedValues() {
        #expect(OverlayMode(rawValue: "off") == .off)
        #expect(OverlayMode(rawValue: "notch") == .notch)
        #expect(OverlayMode(rawValue: "floatingWidget") == .floatingWidget)
        #expect(OverlayMode.fallback == .off)
    }

    @Test("migrates the legacy display mode once")
    func migratesLegacyDisplayMode() {
        let defaults = UserDefaults(suiteName: "overlay-mode-tests")!
        defaults.removePersistentDomain(forName: "overlay-mode-tests")

        defaults.set("menuBar", forKey: OverlayMode.legacyStorageKey)
        OverlayMode.migrateIfNeeded(in: defaults)
        #expect(defaults.string(forKey: OverlayMode.storageKey) == "off")

        // Повторная миграция не перетирает актуальный выбор.
        defaults.set("notch", forKey: OverlayMode.legacyStorageKey)
        OverlayMode.migrateIfNeeded(in: defaults)
        #expect(defaults.string(forKey: OverlayMode.storageKey) == "off")

        defaults.removePersistentDomain(forName: "overlay-mode-tests")
    }
}
