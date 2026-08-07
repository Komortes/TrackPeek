import Testing
@testable import TrackPeek

@Suite("Overlay visibility")
struct OverlayVisibilityTests {
    @Test("off mode and temporary hide always win")
    func offAndTemporaryHideWin() {
        #expect(
            !OverlayVisibility.isVisible(
                mode: .off, temporarilyHidden: false, policy: .always,
                availability: .ready, isPlaying: true
            )
        )
        #expect(
            !OverlayVisibility.isVisible(
                mode: .notch, temporarilyHidden: true, policy: .always,
                availability: .ready, isPlaying: true
            )
        )
    }

    @Test("always policy shows the panel regardless of playback")
    func alwaysPolicy() {
        for availability: PlaybackAvailability in
            [.loading, .ready, .nothingPlaying, .spotifyNotRunning, .unavailable] {
            #expect(
                OverlayVisibility.isVisible(
                    mode: .floatingWidget, temporarilyHidden: false, policy: .always,
                    availability: availability, isPlaying: false
                )
            )
        }
    }

    @Test("whileSourceRunning hides the panel only when the player app is not running")
    func whileSourceRunningPolicy() {
        #expect(
            !OverlayVisibility.isVisible(
                mode: .notch, temporarilyHidden: false, policy: .whileSourceRunning,
                availability: .spotifyNotRunning, isPlaying: false
            )
        )
        // Ошибка ≠ «не запущен»: не прячем панель из-за сбойного ответа.
        for availability: PlaybackAvailability in [.loading, .ready, .nothingPlaying, .unavailable] {
            #expect(
                OverlayVisibility.isVisible(
                    mode: .notch, temporarilyHidden: false, policy: .whileSourceRunning,
                    availability: availability, isPlaying: false
                )
            )
        }
    }

    @Test("whilePlaying follows the play state only")
    func whilePlayingPolicy() {
        #expect(
            OverlayVisibility.isVisible(
                mode: .floatingWidget, temporarilyHidden: false, policy: .whilePlaying,
                availability: .ready, isPlaying: true
            )
        )
        #expect(
            !OverlayVisibility.isVisible(
                mode: .floatingWidget, temporarilyHidden: false, policy: .whilePlaying,
                availability: .ready, isPlaying: false
            )
        )
    }

    @Test("persisted policy values stay stable")
    func persistedValuesStayStable() {
        #expect(OverlayVisibilityPolicy(rawValue: "always") == .always)
        #expect(OverlayVisibilityPolicy(rawValue: "whileSourceRunning") == .whileSourceRunning)
        #expect(OverlayVisibilityPolicy(rawValue: "whilePlaying") == .whilePlaying)
        #expect(OverlayVisibilityPolicy.fallback == .always)
    }
}
