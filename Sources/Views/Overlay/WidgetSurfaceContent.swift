import SwiftUI

/// Содержимое floating-виджета: выбор одной из восьми раскладок. Отделено
/// от `NotchPlayerView` так же, как `NotchSurfaceContent` — получает уже
/// разрешённые `OverlayAppearance`/палитру и не касается `@AppStorage`.
struct WidgetSurfaceContent: View {
    let model: SpotifySpikeModel
    let audioMonitor: SpotifyAudioMonitor
    let lyricsStore: LyricsStore
    let appearance: OverlayAppearance
    let palette: ArtworkPalette
    let layout: NotchWidgetLayout
    let containerSize: CGSize
    let songInfoVisibility: NotchSongInfoVisibility
    let isPointerInside: Bool
    /// «Обложка сбоку» — это тот же раскрытый плеер чёлки в постоянном
    /// размере; переиспользуем NotchSurfaceContent вместо дублирования тела.
    let onCollapse: () -> Void

    private var context: WidgetCardContext {
        WidgetCardContext(
            model: model,
            lyricsStore: lyricsStore,
            audioMonitor: audioMonitor,
            palette: palette,
            coloredProgress: appearance.coloredProgress,
            equalizerSensitivity: appearance.equalizerSensitivityOverride ?? NotchPreferences.equalizerSensitivityFallback
        )
    }

    var body: some View {
        if layout == .cardHorizontal {
            NotchSurfaceContent(
                model: model,
                audioMonitor: audioMonitor,
                lyricsStore: lyricsStore,
                appearance: appearance,
                palette: palette,
                panelState: .expanded,
                containerSize: containerSize,
                revealProgress: 1,
                songInfoVisibility: songInfoVisibility,
                clickEnabled: false,
                onTogglePin: {},
                onCollapse: onCollapse
            )
        } else if let track = model.track, model.availability == .ready {
            switch layout {
            case .pill, .cardHorizontal:
                EmptyView()
            case .miniBar:
                WidgetMiniBar(context: context, track: track)
            case .cardVertical:
                WidgetVerticalCard(
                    context: context,
                    track: track,
                    size: containerSize,
                    lyricsEnabled: appearance.lyricsEnabled.wrappedValue
                )
            case .artworkSquare:
                WidgetArtworkSquare(
                    context: context,
                    track: track,
                    size: containerSize,
                    isHovering: isPointerInside
                )
            case .lyricsCard:
                WidgetLyricsCard(context: context, track: track)
            case .karaokeCard:
                WidgetKaraokeCard(context: context, track: track)
            case .equalizerCard:
                WidgetEqualizerCard(context: context, track: track)
            }
        } else {
            PlayerStateView(availability: model.availability, sourceName: model.activeSourceDisplayName) {
                Task { await model.refresh() }
            }
            .padding(14)
        }
    }
}
