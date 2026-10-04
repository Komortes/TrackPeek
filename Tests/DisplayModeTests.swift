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

@Suite("Player app selection")
struct PlayerAppLauncherTests {
    @Test("explicit preference overrides a previous source and running apps")
    func explicitPreferenceWins() {
        #expect(PlayerAppLauncher.sourceToOpen(
            preference: .spotify, resolvedSource: .appleMusic,
            spotifyRunning: false, musicRunning: true
        ) == .spotify)
        #expect(PlayerAppLauncher.sourceToOpen(
            preference: .appleMusic, resolvedSource: .spotify,
            spotifyRunning: true, musicRunning: false
        ) == .appleMusic)
    }

    @Test("automatic mode opens the displayed Music source when both apps run")
    func automaticModeMatchesDisplayedSource() {
        #expect(PlayerAppLauncher.sourceToOpen(
            preference: .auto, resolvedSource: .appleMusic,
            spotifyRunning: true, musicRunning: true
        ) == .appleMusic)
    }

    @Test("automatic mode can reopen the displayed source after it closes")
    func automaticModeCanReopenSource() {
        #expect(PlayerAppLauncher.sourceToOpen(
            preference: .auto, resolvedSource: .appleMusic,
            spotifyRunning: false, musicRunning: false
        ) == .appleMusic)
    }

    @Test("automatic mode falls back to running apps before a source is resolved")
    func automaticModeFallback() {
        #expect(PlayerAppLauncher.sourceToOpen(
            preference: .auto, resolvedSource: nil,
            spotifyRunning: true, musicRunning: true
        ) == .spotify)
        #expect(PlayerAppLauncher.sourceToOpen(
            preference: .auto, resolvedSource: nil,
            spotifyRunning: true, musicRunning: false
        ) == .spotify)
        #expect(PlayerAppLauncher.sourceToOpen(
            preference: .auto, resolvedSource: nil,
            spotifyRunning: false, musicRunning: true
        ) == .appleMusic)
        #expect(PlayerAppLauncher.sourceToOpen(
            preference: .auto, resolvedSource: nil,
            spotifyRunning: false, musicRunning: false
        ) == .spotify)
    }
}
