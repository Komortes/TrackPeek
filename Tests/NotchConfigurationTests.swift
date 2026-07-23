import AppKit
import CoreGraphics
import SwiftUI
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

    @Test("finishes revealing exactly at the configured expanded height")
    func finishesRevealingAtConfiguredExpandedHeight() {
        // A taller configured panel must not stay mid-reveal once its own
        // resize finishes, and a shorter one must not have already finished
        // revealing before its resize actually completes.
        #expect(NotchResponsiveLayout.revealProgress(forHeight: 188, expandedHeight: 188) == 1)
        #expect(NotchResponsiveLayout.revealProgress(forHeight: 172, expandedHeight: 172) == 1)
        #expect(NotchResponsiveLayout.revealProgress(forHeight: 176, expandedHeight: 188) < 1)
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
    }

    @Test("draws the compact notch as one closed rounded silhouette")
    func drawsCompactNotchAsOneClosedSilhouette() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 36)
        let lineWidth: CGFloat = 1.5
        let shape = NotchSilhouetteShape(bottomCornerRadius: 13)
        let lowerOutlineShape = NotchSilhouetteShape(
            bottomCornerRadius: 13,
            includesTopEdge: false
        )
        let silhouette = shape.path(in: bounds)
        let strokeCenterline = lowerOutlineShape
            .inset(by: lineWidth / 2)
            .path(in: bounds)

        let outline = strokeCenterline.cgPath.copy(
            strokingWithWidth: lineWidth,
            lineCap: .butt,
            lineJoin: .round,
            miterLimit: 10,
            transform: .identity
        )

        #expect(silhouette.contains(CGPoint(x: bounds.midX, y: bounds.maxY - 0.5)))
        #expect(!silhouette.contains(CGPoint(x: 0.5, y: bounds.maxY - 0.5)))
        #expect(
            outline.contains(
                CGPoint(x: bounds.midX, y: bounds.maxY - lineWidth / 2)
            )
        )
        #expect(
            !outline.contains(
                CGPoint(x: bounds.midX, y: bounds.minY + lineWidth / 2)
            )
        )
    }

    @Test("clips compact glow out of both rounded bottom corners")
    @MainActor
    func clipsCompactGlowOutOfRoundedCorners() async {
        let size = CGSize(width: 320, height: 36)
        let suiteName = "NotchConfigurationTests.compactGlow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(NotchPulseMode.glow.rawValue, forKey: NotchPreferences.pulseModeKey)
        defaults.set(13.0, forKey: NotchPreferences.cornerRadiusKey)

        let model = SpotifySpikeModel(
            provider: NotchRenderingSpotifyProvider(
                track: SpotifyTrack(
                    title: "Test track",
                    artist: "Test artist",
                    isPlaying: true
                )
            )
        )
        await model.refresh()

        let renderedView = ZStack {
            Color(red: 0, green: 1, blue: 0)

            NotchPlayerView(
                model: model,
                audioMonitor: SpotifyAudioMonitor(),
                lyricsStore: LyricsStore(),
                pointerState: NotchPointerState(),
                panelLayoutState: NotchPanelLayoutState(size: size),
                onStateChange: { _ in }
            )
            .defaultAppStorage(defaults)
        }
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: renderedView)
        renderer.isOpaque = false
        renderer.scale = 1

        guard let image = renderer.cgImage else {
            Issue.record("Unable to render the compact notch")
            return
        }
        let bitmap = NSBitmapImageRep(cgImage: image)

        let inset = 2
        let cornerRows = [inset, bitmap.pixelsHigh - inset - 1]
        let rowsShowingBackground = cornerRows.filter { y in
            guard
                let left = bitmap.colorAt(x: inset, y: y),
                let right = bitmap.colorAt(x: bitmap.pixelsWide - inset - 1, y: y)
            else {
                return false
            }

            return [left, right].allSatisfy { color in
                color.greenComponent > 0.98
                    && color.redComponent < 0.02
                    && color.blueComponent < 0.02
            }
        }

        #expect(rowsShowingBackground.count == 1)
    }

    @Test("balances compact artwork and equalizer around the center content")
    func balancesCompactAccessoryPlacement() {
        #expect(NotchResponsiveLayout.compactArtworkSize == 24)
        #expect(NotchResponsiveLayout.compactEqualizerSize == CGSize(width: 24, height: 16))
        #expect(NotchResponsiveLayout.compactHorizontalPadding == 10)
        #expect(NotchResponsiveLayout.compactEqualizerVerticalOffset == -2)
        #expect(
            NotchResponsiveLayout.compactHorizontalPadding
                + NotchResponsiveLayout.compactArtworkSize / 2
                == NotchResponsiveLayout.compactHorizontalPadding
                + NotchResponsiveLayout.compactEqualizerSize.width / 2
        )
    }

    @Test("tracks only valid visible panel sizes")
    @MainActor
    func tracksOnlyValidVisiblePanelSizes() {
        let layoutState = NotchPanelLayoutState(
            size: CGSize(width: 320, height: 36)
        )

        layoutState.updateVisibleSize(CGSize(width: 416, height: 176))
        #expect(layoutState.size == CGSize(width: 416, height: 176))

        layoutState.updateVisibleSize(.zero)
        #expect(layoutState.size == CGSize(width: 416, height: 176))
    }

    @Test("uses one measured panel motion contract")
    func usesMeasuredPanelMotionContract() {
        #expect(NotchMotion.resizeDuration == 0.42)
        #expect(NotchMotion.hoverExitGrace == 0.14)

        #expect(NotchMotion.resizeDuration < 0.5)
    }

    @Test("song information visibility follows playback state")
    func songInfoVisibilityFollowsPlayback() {
        #expect(NotchSongInfoVisibility.always.shouldShow(isPlaying: false))
        #expect(NotchSongInfoVisibility.whilePlaying.shouldShow(isPlaying: true))
        #expect(!NotchSongInfoVisibility.whilePlaying.shouldShow(isPlaying: false))
        #expect(!NotchSongInfoVisibility.never.shouldShow(isPlaying: true))
    }

    @Test("expands for hover or pin and shows a light notification for new songs")
    func expansionPolicyUsesEnabledSources() {
        #expect(
            NotchExpansionPolicy.state(
                hoverReady: true,
                hoverEnabled: true,
                isPinned: false,
                clickEnabled: true,
                notificationVisible: false
            ) == .expanded
        )
        #expect(
            NotchExpansionPolicy.state(
                hoverReady: true,
                hoverEnabled: false,
                isPinned: true,
                clickEnabled: false,
                notificationVisible: false
            ) == .collapsed
        )
        // Новая песня показывает лёгкое уведомление, а не полный плеер.
        #expect(
            NotchExpansionPolicy.state(
                hoverReady: false,
                hoverEnabled: false,
                isPinned: false,
                clickEnabled: false,
                notificationVisible: true
            ) == .notification
        )
        // Наведение имеет приоритет над уведомлением.
        #expect(
            NotchExpansionPolicy.state(
                hoverReady: true,
                hoverEnabled: true,
                isPinned: false,
                clickEnabled: false,
                notificationVisible: true
            ) == .expanded
        )
    }
}

private actor NotchRenderingSpotifyProvider: SpotifyPlaybackProviding {
    let track: SpotifyTrack

    init(track: SpotifyTrack) {
        self.track = track
    }

    func fetchCurrentTrack() -> SpotifyTrack { track }
    func playPause() {}
    func nextTrack() {}
    func previousTrack() {}
    func seek(to _: TimeInterval) {}
}
