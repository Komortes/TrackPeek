import AppKit
import SwiftUI

/// Контейнер экранного плеера: читает настройки активной поверхности
/// (чёлка или виджет), собирает их в `OverlayAppearance` и отдаёт готовое
/// содержимое — `NotchSurfaceContent` либо `WidgetSurfaceContent` — под
/// общей отделкой `OverlayChrome`. Сам контейнер не знает, как рисуется
/// компактная полоска или карточка виджета; это разделение — то, что
/// раньше было одним 960-строчным файлом.
struct NotchPlayerView: View {
    let model: SpotifySpikeModel
    let audioMonitor: SpotifyAudioMonitor
    let lyricsStore: LyricsStore
    let pointerState: NotchPointerState
    let panelLayoutState: NotchPanelLayoutState
    let onStateChange: (NotchPanelState) -> Void

    @AppStorage(NotchPreferences.hoverEnabledKey)
    private var hoverEnabled = NotchPreferences.hoverEnabledFallback
    @AppStorage(NotchPreferences.clickEnabledKey)
    private var clickEnabled = NotchPreferences.clickEnabledFallback
    @AppStorage(NotchPreferences.hoverDelayKey)
    private var hoverDelay = NotchPreferences.hoverDelayFallback
    @AppStorage(NotchPreferences.hapticFeedbackKey)
    private var hapticFeedback = NotchPreferences.hapticFeedbackFallback
    @AppStorage(NotchPreferences.notificationsEnabledKey)
    private var notificationsEnabled = NotchPreferences.notificationsEnabledFallback
    @AppStorage(NotchPreferences.notificationDurationKey)
    private var notificationDuration = NotchPreferences.notificationDurationFallback
    @AppStorage(NotchPreferences.songInfoVisibilityKey)
    private var songInfoVisibilityRawValue = NotchSongInfoVisibility.fallback.rawValue
    @AppStorage(NotchPreferences.coloredProgressKey)
    private var coloredProgress = NotchPreferences.coloredProgressFallback
    @AppStorage(NotchPreferences.coloredWaveformKey)
    private var coloredWaveform = NotchPreferences.coloredWaveformFallback
    @AppStorage(NotchPreferences.outlineShimmerKey)
    private var outlineShimmer = NotchPreferences.outlineShimmerFallback
    @AppStorage(NotchPreferences.outlineWidthKey)
    private var outlineWidth = NotchPreferences.outlineWidthFallback
    @AppStorage(NotchPreferences.pulseModeKey)
    private var pulseModeRawValue = NotchPulseMode.fallback.rawValue
    @AppStorage(NotchPreferences.colorSourceKey)
    private var colorSourceRawValue = NotchColorSource.fallback.rawValue
    @AppStorage(NotchPreferences.cornerRadiusKey)
    private var cornerRadius = NotchPreferences.cornerRadiusFallback
    @AppStorage(NotchPreferences.widthKey)
    private var notchWidth = NotchPreferences.widthFallback
    @AppStorage(NotchPreferences.heightAdjustmentKey)
    private var heightAdjustment = NotchPreferences.heightAdjustmentFallback
    @AppStorage(NotchPreferences.lyricsEnabledKey)
    private var lyricsEnabled = NotchPreferences.lyricsEnabledFallback
    @AppStorage(OverlayMode.storageKey)
    private var overlayModeRawValue = OverlayMode.fallback.rawValue
    @AppStorage(WidgetPreferences.layoutKey)
    private var widgetLayoutRawValue = NotchWidgetLayout.fallback.rawValue
    @AppStorage(WidgetPreferences.outlineShimmerKey)
    private var widgetOutlineShimmer = NotchPreferences.outlineShimmerFallback
    @AppStorage(WidgetPreferences.outlineWidthKey)
    private var widgetOutlineWidth = NotchPreferences.outlineWidthFallback
    @AppStorage(WidgetPreferences.pulseModeKey)
    private var widgetPulseModeRawValue = NotchPulseMode.fallback.rawValue
    @AppStorage(WidgetPreferences.glassBackgroundKey)
    private var widgetGlassBackground = false
    @AppStorage(WidgetPreferences.widthKey)
    private var widgetWidth = NotchPreferences.widthFallback
    @AppStorage(WidgetPreferences.coloredProgressKey)
    private var widgetColoredProgress = NotchPreferences.coloredProgressFallback
    @AppStorage(WidgetPreferences.coloredWaveformKey)
    private var widgetColoredWaveform = NotchPreferences.coloredWaveformFallback
    @AppStorage(WidgetPreferences.colorSourceKey)
    private var widgetColorSourceRawValue = NotchColorSource.fallback.rawValue
    @AppStorage(WidgetPreferences.equalizerSensitivityKey)
    private var widgetEqualizerSensitivity = NotchPreferences.equalizerSensitivityFallback
    @AppStorage(WidgetPreferences.lyricsEnabledKey)
    private var widgetLyricsEnabled = NotchPreferences.lyricsEnabledFallback

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var interaction = NotchInteractionState()
    @State private var artworkPalette = ArtworkPalette.fallback
    @State private var shimmerAngle = Angle.degrees(0)

    private var songInfoVisibility: NotchSongInfoVisibility {
        NotchSongInfoVisibility(rawValue: songInfoVisibilityRawValue) ?? .fallback
    }

    private var colorSource: NotchColorSource {
        NotchColorSource(
            rawValue: isPillMode ? widgetColorSourceRawValue : colorSourceRawValue
        ) ?? .fallback
    }

    // Каждая поверхность владеет своими значениями; здесь выбирается набор
    // активной поверхности и они собираются в один `OverlayAppearance`.
    private var effectiveWidth: Double {
        isPillMode ? widgetWidth : notchWidth
    }

    private var sensitivityOverride: Double? {
        isPillMode ? widgetEqualizerSensitivity : nil
    }

    private var pulseMode: NotchPulseMode {
        NotchPulseMode(
            rawValue: isPillMode ? widgetPulseModeRawValue : pulseModeRawValue
        ) ?? .fallback
    }

    private var appearance: OverlayAppearance {
        OverlayAppearance(
            width: effectiveWidth,
            coloredProgress: isPillMode ? widgetColoredProgress : coloredProgress,
            coloredWaveform: isPillMode ? widgetColoredWaveform : coloredWaveform,
            colorSource: colorSource,
            pulseMode: pulseMode,
            outlineShimmer: isPillMode ? widgetOutlineShimmer : outlineShimmer,
            outlineWidth: isPillMode ? widgetOutlineWidth : outlineWidth,
            equalizerSensitivityOverride: sensitivityOverride,
            lyricsEnabled: isPillMode ? $widgetLyricsEnabled : $lyricsEnabled
        )
    }

    /// Пилюльный режим floating-виджета: та же панель, но со скруглённым верхом.
    private var isPillMode: Bool {
        OverlayMode(rawValue: overlayModeRawValue) == .floatingWidget
    }

    /// Активная карточная раскладка виджета; `nil` — обычная пилюля/чёлка.
    private var cardLayout: NotchWidgetLayout? {
        guard isPillMode else { return nil }
        let layout = NotchWidgetLayout(rawValue: widgetLayoutRawValue) ?? .fallback
        return layout.isAlwaysExpanded ? layout : nil
    }

    /// Нужна ли загрузка текста: включён тумблер или выбрана лирическая раскладка.
    private var lyricsNeeded: Bool {
        appearance.lyricsEnabled.wrappedValue
            || cardLayout == .lyricsCard
            || cardLayout == .karaokeCard
    }

    private struct PaletteRequest: Equatable {
        let url: URL?
        let source: NotchColorSource
    }

    private struct LyricsTaskKey: Equatable {
        let identity: String?
        let enabled: Bool
    }

    private var paletteRequest: PaletteRequest {
        PaletteRequest(url: model.track?.artworkURL, source: colorSource)
    }

    private var audioLevel: Double {
        guard
            !reduceMotion,
            let track = model.track,
            track.isPlaying,
            model.availability == .ready
        else {
            return 0
        }

        let level = audioMonitor.spectrum.magnitudeSquared / Double(AudioSpectrum.bandCount)
        return min(max(level, 0), 1)
    }

    private var pulseScale: CGFloat {
        guard pulseMode == .scale else { return 1 }
        return 1 + CGFloat(audioLevel) * 0.025
    }

    private var glowOpacity: Double {
        guard pulseMode == .glow else { return 0 }
        return 0.18 + audioLevel * 0.5
    }

    private var panelState: NotchPanelState {
        interaction.panelState(
            cardLayoutActive: cardLayout != nil,
            hoverEnabled: hoverEnabled,
            clickEnabled: clickEnabled
        )
    }

    private var isExpanded: Bool {
        panelState == .expanded
    }

    private var trackIdentity: String? {
        model.track.map { "\($0.title)\u{1F}\($0.artist)" }
    }

    var body: some View {
        GeometryReader { proxy in
            let expandedHeight = NotchPreferences.expandedSize(
                width: effectiveWidth,
                heightAdjustment: isPillMode ? 0 : heightAdjustment
            ).height
            let revealProgress = NotchResponsiveLayout.revealProgress(
                forHeight: proxy.size.height,
                expandedHeight: expandedHeight
            )

            Group {
                if let layout = cardLayout {
                    WidgetSurfaceContent(
                        model: model,
                        audioMonitor: audioMonitor,
                        lyricsStore: lyricsStore,
                        appearance: appearance,
                        palette: artworkPalette,
                        layout: layout,
                        containerSize: proxy.size,
                        songInfoVisibility: songInfoVisibility,
                        isPointerInside: pointerState.isInside,
                        onCollapse: { interaction.collapse() }
                    )
                } else {
                    NotchSurfaceContent(
                        model: model,
                        audioMonitor: audioMonitor,
                        lyricsStore: lyricsStore,
                        appearance: appearance,
                        palette: artworkPalette,
                        panelState: panelState,
                        containerSize: proxy.size,
                        revealProgress: revealProgress,
                        songInfoVisibility: songInfoVisibility,
                        clickEnabled: clickEnabled,
                        onTogglePin: { interaction.togglePin() },
                        onCollapse: { interaction.collapse() }
                    )
                }
            }
            .overlayChrome(
                OverlayChromeConfiguration(
                    containerSize: proxy.size,
                    revealProgress: revealProgress,
                    cornerRadius: cornerRadius,
                    isPillMode: isPillMode,
                    palette: artworkPalette,
                    pulseMode: pulseMode,
                    pulseScale: pulseScale,
                    glowOpacity: glowOpacity,
                    outlineShimmer: appearance.outlineShimmer,
                    outlineWidth: appearance.outlineWidth,
                    shimmerAngle: shimmerAngle,
                    coloredWaveform: appearance.coloredWaveform,
                    isExpanded: isExpanded,
                    glassBackgroundURL: (isPillMode && widgetGlassBackground)
                        ? model.track?.artworkURL
                        : nil,
                    reduceMotion: reduceMotion,
                    reduceTransparency: reduceTransparency
                )
            )
        }
        .frame(
            width: panelLayoutState.size.width,
            height: panelLayoutState.size.height,
            alignment: .top
        )
        .contentShape(Rectangle())
        .environment(\.colorScheme, .dark)
        .playerContextMenu(track: model.track, sourceName: model.activeSourceDisplayName) {
            Task { await model.refresh() }
        }
        .onChange(of: pointerState.isInside) { _, isInside in
            interaction.handleHover(
                isInside: isInside,
                pointerIsInside: { pointerState.isInside },
                enabled: hoverEnabled,
                delay: NotchPreferences.clampedHoverDelay(hoverDelay)
            )
        }
        .onChange(of: panelState) { previousState, state in
            onStateChange(state)

            if state == .expanded && previousState != .expanded && hapticFeedback {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .now
                )
            }
        }
        .onChange(of: trackIdentity) { oldValue, newValue in
            interaction.handleTrackChange(
                from: oldValue,
                to: newValue,
                notificationsEnabled: notificationsEnabled,
                duration: NotchPreferences.clampedNotificationDuration(notificationDuration)
            )
        }
        .task(id: LyricsTaskKey(identity: trackIdentity, enabled: lyricsNeeded)) {
            guard lyricsNeeded, let track = model.track else { return }
            lyricsStore.prepare(for: track)
        }
        .task(id: paletteRequest) {
            switch colorSource {
            case .artwork:
                artworkPalette = .fallback
                artworkPalette = await ArtworkPaletteLoader.shared.palette(
                    for: model.track?.artworkURL
                )
            case .systemAccent:
                artworkPalette = .systemAccent
            }
        }
        .onAppear {
            onStateChange(panelState)
            interaction.handleHover(
                isInside: pointerState.isInside,
                pointerIsInside: { pointerState.isInside },
                enabled: hoverEnabled,
                delay: NotchPreferences.clampedHoverDelay(hoverDelay)
            )

            if !reduceMotion {
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    shimmerAngle = .degrees(360)
                }
            }
        }
        .onDisappear {
            interaction.cancelPendingTasks()
        }
    }
}
