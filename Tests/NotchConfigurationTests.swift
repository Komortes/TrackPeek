import CoreGraphics
import Testing
@testable import TrackPeek

@Suite("Notch configuration")
struct NotchConfigurationTests {
    @Test("keeps persisted enum values stable")
    func persistedValuesStayStable() {
        #expect(NotchDisplayTarget(rawValue: "mainDisplay") == .mainDisplay)
        #expect(NotchDisplayTarget(rawValue: "notchedDisplay") == .notchedDisplay)
        #expect(NotchDisplayTarget(rawValue: "allDisplays") == .allDisplays)
        #expect(NotchSongInfoVisibility(rawValue: "whilePlaying") == .whilePlaying)
    }

    @Test("clamps editable numeric preferences")
    func clampsNumericPreferences() {
        #expect(NotchPreferences.clampedWidth(100) == NotchPreferences.widthRange.lowerBound)
        #expect(NotchPreferences.clampedWidth(900) == NotchPreferences.widthRange.upperBound)
        #expect(NotchPreferences.clampedHoverDelay(0) == NotchPreferences.hoverDelayRange.lowerBound)
        #expect(NotchPreferences.clampedNotificationDuration(20) == NotchPreferences.notificationDurationRange.upperBound)
    }

    @Test("derives compact and expanded panel sizes from preferences")
    func derivesPanelSizes() {
        let compact = NotchPreferences.compactSize(width: 320, heightAdjustment: 4)
        let expanded = NotchPreferences.expandedSize(width: 320, heightAdjustment: 4)

        #expect(compact == CGSize(width: 320, height: 40))
        #expect(expanded == CGSize(width: 416, height: 192))
    }

    @Test("song information visibility follows playback state")
    func songInfoVisibilityFollowsPlayback() {
        #expect(NotchSongInfoVisibility.always.shouldShow(isPlaying: false))
        #expect(NotchSongInfoVisibility.whilePlaying.shouldShow(isPlaying: true))
        #expect(!NotchSongInfoVisibility.whilePlaying.shouldShow(isPlaying: false))
        #expect(!NotchSongInfoVisibility.never.shouldShow(isPlaying: true))
    }
}
