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
        #expect(expanded == CGSize(width: 416, height: 180))
        #expect(
            NotchPreferences.expandedSize(width: 240, heightAdjustment: 0)
                == CGSize(width: 352, height: 176)
        )
    }

    @Test("adapts artwork to narrow and transient panel sizes")
    func adaptsArtworkToPanelSize() {
        let narrowArtworkSize = NotchResponsiveLayout.artworkSize(
            in: CGSize(width: 352, height: 176)
        )

        #expect(abs(narrowArtworkSize - 63.36) < 0.001)
        #expect(
            NotchResponsiveLayout.artworkSize(in: CGSize(width: 240, height: 80))
                == 32
        )
    }

    @Test("reveals expanded content only after it fits")
    func revealsExpandedContentAfterItFits() {
        #expect(NotchResponsiveLayout.revealProgress(forHeight: 80) == 0)
        #expect(NotchResponsiveLayout.revealProgress(forHeight: 120) > 0)
        #expect(NotchResponsiveLayout.revealProgress(forHeight: 176) == 1)
    }

    @Test("keeps compact notch bottom edge rounded and visibly outlined")
    func keepsCompactNotchChromeVisible() {
        let radius = NotchResponsiveLayout.bottomCornerRadius(
            preferredRadius: 20,
            revealProgress: 0,
            height: 36
        )

        #expect(radius == 18)
        #expect(NotchResponsiveLayout.baseOutlineOpacity(revealProgress: 0) > 0)
        #expect(NotchResponsiveLayout.baseOutlineOpacity(revealProgress: 1) == 0)
        #expect(NotchResponsiveLayout.outlineInset(revealProgress: 0) == 1)
        #expect(NotchResponsiveLayout.outlineInset(revealProgress: 1) == 0)
    }

    @Test("uses one measured panel motion contract")
    func usesMeasuredPanelMotionContract() {
        #expect(NotchMotion.resizeDuration == 0.36)
        #expect(NotchMotion.hoverExitGrace == 0.14)

        #expect(NotchMotion.resizeDuration < 0.4)
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
