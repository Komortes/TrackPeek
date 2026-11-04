import SwiftUI

/// A paused, local sample rendered by the same views as the desktop player.
/// It has no connection to the user's player, artwork network or audio capture.
struct SettingsPlayerPreview: View {
    enum Surface {
        case widget(NotchWidgetLayout)
        case notch(NotchContentLayout)
    }

    let surface: Surface
    @State private var model = SpotifySpikeModel(provider: SettingsPreviewPlayback())
    @State private var lyrics = LyricsStore(provider: SettingsPreviewLyrics())
    @State private var audio = SpotifyAudioMonitor()
    @Environment(\.displayScale) private var displayScale


    private var size: CGSize {
        switch surface {
        case .widget(let layout):
            WidgetPreferences.cardSize(layout: layout, width: 280, heightAdjustment: 0)
        case .notch(let layout):
            layout.size(for: .expanded, width: 280, heightAdjustment: 0, topInset: 32)
        }
    }

    private var appearance: OverlayAppearance {
        OverlayAppearance(width: 280, coloredProgress: true, coloredWaveform: true,
            colorSource: .artwork, pulseMode: .off, outlineShimmer: false, outlineWidth: 1,
            equalizerSensitivityOverride: 1, lyricsEnabled: .constant(false))
    }

    private var shape: NotchSilhouetteShape {
        switch surface {
        case .widget: NotchSilhouetteShape(bottomCornerRadius: 18, topCornerRadius: 18)
        case .notch: NotchSilhouetteShape(bottomCornerRadius: 18)
        }
    }

    private var image: CGImage? {
        guard let track = model.track else { return nil }
        // Track the local lyrics cache so the still image refreshes when ready.
        _ = lyrics.state(for: track)
        let renderer = ImageRenderer(content: content
            .frame(width: size.width, height: size.height)
            .background(.black)
            .clipShape(shape)
            .overlay { shape.stroke(.white.opacity(0.12), lineWidth: 1) }
            .environment(\.colorScheme, .dark)
            .environment(\.resourceSaving, true))
        renderer.scale = displayScale
        return renderer.cgImage
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = max(0.1, min(1, (geometry.size.width - 32) / size.width, (geometry.size.height - 24) / size.height))
            if let image {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .frame(width: size.width * scale, height: size.height * scale)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .accessibilityHidden(true)
        .task {
            guard model.track == nil else { return }
            await model.refresh()
            if let track = model.track { lyrics.prepare(for: track) }
        }
    }

    @ViewBuilder private var content: some View {
        switch surface {
        case .notch(.focus):
            NotchFocusView(model: model, state: .expanded, size: size, topInset: 32,
                cameraWidth: 180, isVisible: false, clickEnabled: false,
                onTogglePin: {}, onCollapse: {})
        case .notch, .widget(.pill):
            let collapsed = if case .widget = surface { true } else { false }
            NotchSurfaceContent(model: model, audioMonitor: audio, lyricsStore: lyrics,
                appearance: appearance, palette: .fallback,
                panelState: collapsed ? .collapsed : .expanded, containerSize: size,
                revealProgress: collapsed ? 0 : 1, songInfoVisibility: .always,
                clickEnabled: false, onTogglePin: {}, onCollapse: {})
        case .widget(let layout):
            WidgetSurfaceContent(model: model, audioMonitor: audio, lyricsStore: lyrics,
                appearance: appearance, palette: .fallback, layout: layout, containerSize: size,
                songInfoVisibility: .always, isPointerInside: false, isVisible: false, onCollapse: {},
                showsSecondaryControls: false)
        }
    }
}

private struct SettingsPreviewPlayback: SpotifyPlaybackProviding {
    func fetchCurrentTrack() -> SpotifyTrack {
        SpotifyTrack(title: String(localized: "preview.trackTitle", defaultValue: "First Light"),
            artist: "TrackPeek", duration: 240, position: 65, isPlaying: false)
    }
    func activeSource() -> PlaybackSource { .spotify }
    func playPause() {}
    func nextTrack() {}
    func previousTrack() {}
    func seek(to _: TimeInterval) {}
    func setShuffle(_: Bool) {}
    func setRepeat(_: RepeatMode) {}
    func setVolume(_: Int) {}
}

private struct SettingsPreviewLyrics: LyricsProviding {
    func fetchLyrics(for _: LyricsRequest) -> TrackLyrics? {
        TrackLyrics(syncedLines: [
            .init(time: 0, text: String(localized: "preview.lyrics.first", defaultValue: "The day begins with a song")),
            .init(time: 40, text: String(localized: "preview.lyrics.current", defaultValue: "A little music, wherever you are")),
            .init(time: 90, text: String(localized: "preview.lyrics.next", defaultValue: "Keep this moment close"))
        ], plainText: nil)
    }
}
