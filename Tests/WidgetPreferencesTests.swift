import AppKit
import Foundation
import SwiftUI
import Testing
@testable import TrackPeek

@Suite("Widget preferences")
struct WidgetPreferencesTests {
    @Test("repeated migration does not clobber a value the user already changed")
    func repeatedMigrationDoesNotClobberExistingValue() {
        // Тест-хост запускает настоящий TrackPeekAppDelegate перед тестами, и тот
        // уже вызвал WidgetPreferences.registerDefaults() на .standard. Регистрация
        // UserDefaults общая на процесс (не на конкретный suite), поэтому
        // изолированный suite не может воспроизвести «ключ ещё не существует» —
        // отсюда здесь проверяется только идемпотентность повторного вызова.
        let suiteName = "widget-preferences-tests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        defaults.set(340.0, forKey: WidgetPreferences.widthKey)
        WidgetPreferences.migrateDefaultsIfNeeded(in: defaults)
        #expect(defaults.double(forKey: WidgetPreferences.widthKey) == 340.0)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("card size for the pill layout matches the compact notch size")
    func pillCardSizeMatchesCompactSize() {
        let size = WidgetPreferences.cardSize(layout: .pill, width: 320, heightAdjustment: 0)
        let expected = NotchPreferences.compactSize(width: 320, heightAdjustment: 0)
        #expect(size == expected)
    }

    @Test("window policy keys use stable raw strings and defaults")
    func windowPolicyKeysStable() {
        #expect(WidgetPreferences.alwaysOnTopKey == "widgetAlwaysOnTop")
        #expect(WidgetPreferences.allSpacesKey == "widgetAllSpaces")
        #expect(WidgetPreferences.hideInFullscreenKey == "widgetHideInFullscreen")
        #expect(WidgetPreferences.positionLockedKey == "widgetPositionLocked")

        let suiteName = "widget-window-policy-defaults"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        WidgetPreferences.registerDefaults(in: defaults)
        #expect(defaults.bool(forKey: WidgetPreferences.alwaysOnTopKey))
        #expect(defaults.bool(forKey: WidgetPreferences.allSpacesKey))
        #expect(!defaults.bool(forKey: WidgetPreferences.hideInFullscreenKey))
        #expect(!defaults.bool(forKey: WidgetPreferences.positionLockedKey))
        defaults.removePersistentDomain(forName: suiteName)
    }
}

extension WidgetPreferencesTests {
    @Test("Edge keeps its narrow fixed size independently of other templates")
    func edgeSize() {
        for width in [260.0, 320, 500] {
            #expect(WidgetPreferences.cardSize(layout: .edge, width: width, heightAdjustment: 40)
                    == CGSize(width: 72, height: 224))
        }
        #expect(NotchWidgetLayout.edge.family == .compact)
        #expect(NotchWidgetLayout.edge.isAlwaysExpanded)
    }

    @Test("Edge placement respects the visible frame on either display edge")
    func edgePlacement() {
        let bounds = CGRect(x: -1920, y: 25, width: 1860, height: 1000)
        let size = CGSize(width: 72, height: 224)
        let left = WidgetPreferences.edgeOrigin(in: bounds, size: size, onRight: false)
        let right = WidgetPreferences.edgeOrigin(in: bounds, size: size, onRight: true)
        #expect(left.x == bounds.minX + 12)
        #expect(right.x + size.width == bounds.maxX - 12)
        #expect(left.y + size.height / 2 == bounds.midY)
        #expect(left.y == right.y)
        #expect(bounds.contains(CGRect(origin: left, size: size)))
        #expect(bounds.contains(CGRect(origin: right, size: size)))
    }
}

@MainActor
@Suite("Widget lyrics demand", .serialized, .timeLimit(.minutes(1)))
struct WidgetLyricsDemandTests {
    @Test("templates without lyrics ignore a saved lyrics switch until a capable template is selected",
          arguments: [NotchWidgetLayout.miniBar, .edge, .artworkSquare, .equalizerCard])
    func unsupportedTemplateDoesNotLoadLyrics(layout: NotchWidgetLayout) async throws {
        let suiteName = "widget-lyrics-demand.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(OverlayMode.floatingWidget.rawValue, forKey: OverlayMode.storageKey)
        defaults.set(layout.rawValue, forKey: WidgetPreferences.layoutKey)
        defaults.set(true, forKey: WidgetPreferences.lyricsEnabledKey)
        defaults.set(NotchColorSource.systemAccent.rawValue, forKey: WidgetPreferences.colorSourceKey)
        defaults.set(false, forKey: WidgetPreferences.outlineShimmerKey)
        defaults.set(NotchPulseMode.off.rawValue, forKey: WidgetPreferences.pulseModeKey)

        let track = SpotifyTrack(title: "Fixture", artist: "Fixture", duration: 240, isPlaying: false)
        let model = SpotifySpikeModel(provider: WidgetLyricsPlaybackProvider(track: track))
        await model.refresh()
        let provider = WidgetLyricsProvider()
        let store = LyricsStore(provider: provider)
        let size = CGSize(width: 360, height: 240)
        let panel = NotchPanelLayoutState(size: size)
        panel.isVisible = true
        let content = NotchPlayerView(
            model: model, audioMonitor: SpotifyAudioMonitor(), lyricsStore: store,
            pointerState: NotchPointerState(), panelLayoutState: panel, onStateChange: { _ in }
        )
        .defaultAppStorage(defaults)
        let host = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderBack(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }

        await settleLayout(host)
        #expect(await provider.requestCount == 0, "A template with no lyrics must not start a lookup")
        #expect(store.state(for: track) == .loading, "No lookup result should have been cached")

        // Positive control: the same mounted view must react to a real preference
        // change and load lyrics once a template that displays them is selected.
        defaults.set(NotchWidgetLayout.cardVertical.rawValue, forKey: WidgetPreferences.layoutKey)
        for _ in 0..<20 {
            if store.state(for: track) == .unavailable { break }
            await settleLayout(host)
        }
        #expect(store.state(for: track) == .unavailable)
        #expect(await provider.requestCount == 1)
        #expect(defaults.bool(forKey: WidgetPreferences.lyricsEnabledKey), "The user's choice stays saved")
    }

    private func settleLayout(_ host: NSView) async {
        for _ in 0..<20 {
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    RunLoop.main.perform(inModes: [.default]) { continuation.resume() }
                }
            }
        }
    }
}

private actor WidgetLyricsProvider: LyricsProviding {
    private(set) var requestCount = 0
    func fetchLyrics(for _: LyricsRequest) -> TrackLyrics? {
        requestCount += 1
        return nil
    }
}

private actor WidgetLyricsPlaybackProvider: SpotifyPlaybackProviding {
    let track: SpotifyTrack
    init(track: SpotifyTrack) { self.track = track }
    func fetchCurrentTrack() -> SpotifyTrack { track }
    func activeSource() -> PlaybackSource { .spotify }
    func playPause() {}
    func nextTrack() {}
    func previousTrack() {}
    func seek(to _: TimeInterval) {}
    func setShuffle(_: Bool) {}
    func setRepeat(_: RepeatMode) {}
    func setVolume(_: Int) {}
}
