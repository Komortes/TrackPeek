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

    @MainActor
    @Test("Reset stays off on the next startup for migrated and already updated profiles",
          arguments: [OverlayMode.notch, .floatingWidget], [false, true])
    func resetDoesNotRestoreLegacyOverlay(legacyMode: OverlayMode, hasCurrentChoice: Bool) throws {
        let suiteName = "overlay-reset.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(legacyMode.rawValue, forKey: OverlayMode.legacyStorageKey)
        if hasCurrentChoice {
            defaults.set(OverlayMode.off.rawValue, forKey: OverlayMode.storageKey)
        }
        OverlayMode.migrateIfNeeded(in: defaults)
        #expect(defaults.string(forKey: OverlayMode.storageKey)
                == (hasCurrentChoice ? OverlayMode.off : legacyMode).rawValue)

        SettingsView.resetAllSettings(in: defaults)
        let stored = defaults.persistentDomain(forName: suiteName) ?? [:]
        #expect(stored[OverlayMode.storageKey] == nil)
        #expect(stored[OverlayMode.legacyStorageKey] == nil)

        let nextStartup = try #require(UserDefaults(suiteName: suiteName))
        OverlayMode.migrateIfNeeded(in: nextStartup)
        let mode = nextStartup.string(forKey: OverlayMode.storageKey).flatMap(OverlayMode.init(rawValue:))
            ?? .fallback
        #expect(mode == .off)
    }

    @MainActor
    @Test("Reset preserves unrelated settings, migration history and other preference domains")
    func resetPreservesUnrelatedPreferences() throws {
        let suiteName = "settings-reset.\(UUID().uuidString)"
        let otherSuiteName = "settings-reset-other.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let otherDefaults = try #require(UserDefaults(suiteName: otherSuiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            otherDefaults.removePersistentDomain(forName: otherSuiteName)
        }
        WidgetPreferences.migrateDefaultsIfNeeded(in: defaults)
        // Check persisted history directly: registered widget width can otherwise
        // make a repeat migration appear to be skipped even without its marker.
        let migrationVersionKey = "widgetPreferencesMigrationVersion"
        let migrationVersion = try #require(
            defaults.persistentDomain(forName: suiteName)?[migrationVersionKey] as? Int
        )
        AppLanguage.ukrainian.save(in: defaults)
        defaults.set(true, forKey: OnboardingWindowController.completedKey)
        defaults.set("keep", forKey: "fixtureNonResettable")
        defaults.set(ResourceUsageMode.economical.rawValue, forKey: ResourceUsageMode.storageKey)
        defaults.set(340.0, forKey: WidgetPreferences.widthKey)
        otherDefaults.set(OverlayMode.notch.rawValue, forKey: OverlayMode.storageKey)
        otherDefaults.set("floatingWidget", forKey: OverlayMode.legacyStorageKey)

        SettingsView.resetAllSettings(in: defaults)

        let stored = try #require(defaults.persistentDomain(forName: suiteName))
        #expect(stored[ResourceUsageMode.storageKey] == nil)
        #expect(stored[WidgetPreferences.widthKey] == nil)
        #expect(stored[migrationVersionKey] as? Int == migrationVersion)
        #expect(AppLanguage.selection(in: defaults, domainName: suiteName) == .ukrainian)
        #expect(defaults.bool(forKey: OnboardingWindowController.completedKey))
        #expect(defaults.string(forKey: "fixtureNonResettable") == "keep")
        #expect(otherDefaults.string(forKey: OverlayMode.storageKey) == "notch")
        #expect(otherDefaults.string(forKey: OverlayMode.legacyStorageKey) == "floatingWidget")
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
