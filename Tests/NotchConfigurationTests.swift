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
        #expect(expanded == CGSize(width: 432, height: 180))
    }

    @Test("uses one short interruptible motion contract")
    func usesShortMotionContract() {
        #expect(NotchMotion.resizeDuration == 0.28)
        #expect(NotchMotion.contentDuration == 0.26)
        #expect(NotchMotion.playbackDuration == 0.24)
        #expect(NotchMotion.controlDuration == 0.14)
        #expect(NotchMotion.equalizerDuration == 0.28)
        #expect(NotchMotion.hoverExitGrace == 0.14)

        #expect(NotchMotion.contentDuration <= NotchMotion.resizeDuration)
        #expect(NotchMotion.resizeDuration <= 0.3)
        #expect(NotchMotion.equalizerDuration <= 0.3)
    }

    @Test("song information visibility follows playback state")
    func songInfoVisibilityFollowsPlayback() {
        #expect(NotchSongInfoVisibility.always.shouldShow(isPlaying: false))
        #expect(NotchSongInfoVisibility.whilePlaying.shouldShow(isPlaying: true))
        #expect(!NotchSongInfoVisibility.whilePlaying.shouldShow(isPlaying: false))
        #expect(!NotchSongInfoVisibility.never.shouldShow(isPlaying: true))
    }

    @Test("expands for enabled hover click or song notification sources")
    func expansionPolicyUsesEnabledSources() {
        #expect(
            NotchExpansionPolicy.shouldExpand(
                hoverReady: true,
                hoverEnabled: true,
                isPinned: false,
                clickEnabled: true,
                notificationVisible: false
            )
        )
        #expect(
            !NotchExpansionPolicy.shouldExpand(
                hoverReady: true,
                hoverEnabled: false,
                isPinned: true,
                clickEnabled: false,
                notificationVisible: false
            )
        )
        #expect(
            NotchExpansionPolicy.shouldExpand(
                hoverReady: false,
                hoverEnabled: false,
                isPinned: false,
                clickEnabled: false,
                notificationVisible: true
            )
        )
    }
}
