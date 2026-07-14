import AppKit
import SwiftUI

struct NotchPlayerView: View {
    let model: SpotifySpikeModel
    let audioMonitor: SpotifyAudioMonitor
    let pointerState: NotchPointerState
    let onExpansionChange: (Bool) -> Void

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hoverReady = false
    @State private var isPinned = false
    @State private var notificationVisible = false
    @State private var artworkPalette = ArtworkPalette.fallback
    @State private var hoverTask: Task<Void, Never>?
    @State private var notificationTask: Task<Void, Never>?
    @State private var shimmerAngle = Angle.degrees(0)

    private var songInfoVisibility: NotchSongInfoVisibility {
        NotchSongInfoVisibility(rawValue: songInfoVisibilityRawValue) ?? .fallback
    }

    private var colorSource: NotchColorSource {
        NotchColorSource(rawValue: colorSourceRawValue) ?? .fallback
    }

    private var pulseMode: NotchPulseMode {
        NotchPulseMode(rawValue: pulseModeRawValue) ?? .fallback
    }

    private struct PaletteRequest: Equatable {
        let url: URL?
        let source: NotchColorSource
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

    private var isExpanded: Bool {
        NotchExpansionPolicy.shouldExpand(
            hoverReady: hoverReady,
            hoverEnabled: hoverEnabled,
            isPinned: isPinned,
            clickEnabled: clickEnabled,
            notificationVisible: notificationVisible
        )
    }

    private var trackIdentity: String? {
        model.track.map { "\($0.title)\u{1F}\($0.artist)" }
    }

    var body: some View {
        GeometryReader { proxy in
            let revealProgress = NotchResponsiveLayout.revealProgress(
                forHeight: proxy.size.height
            )

            ZStack(alignment: .top) {
                compactContent
                    .frame(
                        maxWidth: .infinity,
                        minHeight: min(proxy.size.height, 44),
                        maxHeight: min(proxy.size.height, 44)
                    )
                    .opacity(max(0, 1 - revealProgress * 1.35))
                    .scaleEffect(1 - revealProgress * 0.015, anchor: .top)
                    .allowsHitTesting(!isExpanded)

                expandedContent(in: proxy.size)
                    .opacity(revealProgress)
                    .scaleEffect(0.985 + revealProgress * 0.015, anchor: .top)
                    .allowsHitTesting(isExpanded && revealProgress > 0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                notchBackground
            }
            .clipShape(notchShape(revealProgress: revealProgress, height: proxy.size.height))
            .background {
                if pulseMode == .glow {
                    notchShape(revealProgress: revealProgress, height: proxy.size.height)
                        .fill(artworkPalette.primary.swiftUIColor)
                        .blur(radius: 10)
                        .opacity(glowOpacity)
                        .animation(
                            reduceMotion
                                ? nil
                                : .linear(duration: PlayerMotion.spectrumFrameDuration),
                            value: glowOpacity
                        )
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                ZStack {
                    notchShape(revealProgress: revealProgress, height: proxy.size.height)
                        .strokeBorder(
                            baseOutlineGradient,
                            lineWidth: 1
                        )
                        .opacity(
                            NotchResponsiveLayout.baseOutlineOpacity(
                                revealProgress: revealProgress
                            )
                        )
                        .mask(lowerEdgeMask)
                        .allowsHitTesting(false)

                    if outlineShimmer {
                        // `strokeBorder` stays inside the panel while the mask
                        // removes the bezel-facing top edge. Keeping this effect
                        // separate from the static compact outline means disabling
                        // shimmer no longer removes the visible lower silhouette.
                        notchShape(revealProgress: revealProgress, height: proxy.size.height)
                            .strokeBorder(
                                shimmerGradient,
                                lineWidth: NotchPreferences.clampedOutlineWidth(outlineWidth)
                            )
                            .mask(lowerEdgeMask)
                            .blur(radius: 0.6)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(pulseScale, anchor: .top)
        .animation(
            reduceMotion ? nil : .linear(duration: PlayerMotion.spectrumFrameDuration),
            value: pulseScale
        )
        .contentShape(Rectangle())
        .environment(\.colorScheme, .dark)
        .playerContextMenu(track: model.track) {
            Task { await model.refresh() }
        }
        .onChange(of: pointerState.isInside) { _, isInside in
            handleHover(isInside)
        }
        .onChange(of: isExpanded) { wasExpanded, expanded in
            onExpansionChange(expanded)

            if expanded && !wasExpanded && hapticFeedback {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .now
                )
            }
        }
        .onChange(of: trackIdentity, handleTrackChange)
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
            onExpansionChange(false)
            handleHover(pointerState.isInside)

            if !reduceMotion {
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    shimmerAngle = .degrees(360)
                }
            }
        }
        .onDisappear {
            hoverTask?.cancel()
            notificationTask?.cancel()
        }
    }

    private var shimmerGradient: AngularGradient {
        AngularGradient(
            colors: [
                artworkPalette.primary.swiftUIColor,
                artworkPalette.secondary.swiftUIColor,
                artworkPalette.tertiary.swiftUIColor,
                artworkPalette.primary.swiftUIColor,
            ],
            center: .center,
            angle: shimmerAngle
        )
    }

    private var baseOutlineGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.35),
                artworkPalette.secondary.swiftUIColor,
                artworkPalette.primary.swiftUIColor,
            ],
            startPoint: .top,
            endPoint: .bottomTrailing
        )
    }

    private var lowerEdgeMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.14),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func notchShape(revealProgress: Double, height: CGFloat) -> UnevenRoundedRectangle {
        let radius = NotchResponsiveLayout.bottomCornerRadius(
            preferredRadius: cornerRadius,
            revealProgress: revealProgress,
            height: height
        )
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    private var notchBackground: some View {
        ZStack {
            Color.black.opacity(0.985)

            if coloredWaveform {
                LinearGradient(
                    colors: [
                        artworkPalette.primary.swiftUIColor.opacity(isExpanded ? 0.20 : 0.12),
                        artworkPalette.secondary.swiftUIColor.opacity(isExpanded ? 0.10 : 0.04),
                        .clear,
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                .blendMode(.plusLighter)
            }
        }
        .animation(
            reduceMotion
                ? nil
                : .smooth(duration: PlayerMotion.equalizerDuration, extraBounce: 0),
            value: artworkPalette
        )
    }

    @ViewBuilder
    private var compactContent: some View {
        if let track = model.track, model.availability == .ready {
            HStack(spacing: 10) {
                TrackArtworkView(
                    url: track.artworkURL,
                    size: 24,
                    cornerRadius: 5,
                    showsShadow: false
                )

                if songInfoVisibility.shouldShow(isPlaying: track.isPlaying) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(track.title)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                        .frame(maxWidth: .infinity)
                } else {
                    Spacer(minLength: 0)
                }

                ArtworkEqualizerView(
                    audioMonitor: audioMonitor,
                    isPlaying: track.isPlaying,
                    isVisible: !isExpanded,
                    isColored: coloredWaveform,
                    palette: artworkPalette
                )
                .frame(width: 30, height: 18)
            }
            .padding(.horizontal, 8)
            .onTapGesture {
                guard clickEnabled else { return }
                isPinned.toggle()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Компактный плеер TrackPeek")
            .accessibilityHint("Раскрывает элементы управления воспроизведением")
            .accessibilityAction {
                guard clickEnabled else { return }
                isPinned.toggle()
            }
            .help(clickEnabled ? "Нажмите, чтобы раскрыть плеер" : "Наведите, чтобы раскрыть плеер")
        } else {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.caption.weight(.semibold))

                Text(model.statusText)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func expandedContent(in containerSize: CGSize) -> some View {
        Group {
            expandedContentBody(in: containerSize)
        }
        .animation(
            reduceMotion
                ? nil
                : .smooth(duration: PlayerMotion.playbackDuration, extraBounce: 0),
            value: model.availability
        )
    }

    @ViewBuilder
    private func expandedContentBody(in containerSize: CGSize) -> some View {
        if let track = model.track, model.availability == .ready {
            let isNarrow = containerSize.width < 390
            let artworkSize = NotchResponsiveLayout.artworkSize(in: containerSize)

            HStack(alignment: .center, spacing: isNarrow ? 12 : 15) {
                VStack(spacing: 7) {
                    TrackArtworkView(
                        url: track.artworkURL,
                        size: artworkSize,
                        cornerRadius: min(15, artworkSize * 0.19),
                        showsShadow: true
                    )

                    HStack(spacing: 5) {
                        Circle()
                            .fill(track.isPlaying ? artworkPalette.primary.swiftUIColor : .secondary)
                            .frame(width: 5, height: 5)

                        Text(track.isPlaying ? "ИГРАЕТ" : "ПАУЗА")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .contentTransition(.opacity)
                    }
                    .foregroundStyle(.secondary)
                    .animation(
                        reduceMotion
                            ? nil
                            : .smooth(duration: PlayerMotion.playbackDuration, extraBounce: 0),
                        value: track.isPlaying
                    )
                }
                .frame(width: artworkSize + 4)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .lineLimit(1)

                            Text(track.artist)
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            if !isNarrow, let album = track.album, !album.isEmpty {
                                Text(album)
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            isPinned = false
                            notificationVisible = false
                            hoverReady = false
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 9, weight: .bold))
                                .frame(width: 22, height: 22)
                                .background(.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Свернуть плеер")
                    }

                    Spacer(minLength: 6)

                    PlaybackProgressView(
                        position: track.position,
                        duration: track.duration,
                        isPlaying: track.isPlaying,
                        snapshotDate: model.snapshotDate,
                        onSeek: { position in Task { await model.seek(to: position) } },
                        tint: coloredProgress ? artworkPalette.primary.swiftUIColor : .white
                    )

                    Spacer(minLength: 4)

                    HStack(spacing: 12) {
                        PlaybackControlsView(
                            isPlaying: track.isPlaying,
                            onPrevious: { Task { await model.previousTrack() } },
                            onPlayPause: { Task { await model.togglePlayback() } },
                            onNext: { Task { await model.nextTrack() } },
                            spacing: isNarrow ? 7 : 10
                        )
                        .tint(artworkPalette.primary.swiftUIColor)

                        Spacer(minLength: 8)

                        ArtworkEqualizerView(
                            audioMonitor: audioMonitor,
                            isPlaying: track.isPlaying,
                            isVisible: isExpanded,
                            isColored: coloredWaveform,
                            palette: artworkPalette
                        )
                        .frame(width: isNarrow ? 36 : 48, height: 24)
                    }
                }
            }
            .padding(.horizontal, isNarrow ? 12 : 16)
            .padding(.top, 13)
            .padding(.bottom, 12)
            .transition(
                .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(model.statusText)
                    .font(.callout.weight(.medium))

                Button("Обновить") {
                    Task { await model.refresh() }
                }
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .transition(
                .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
            )
        }
    }

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()

        guard hoverEnabled else {
            hoverReady = false
            return
        }

        guard hovering else {
            hoverTask = Task { @MainActor in
                try? await Task.sleep(
                    for: .milliseconds(Int64(NotchMotion.hoverExitGrace * 1_000))
                )
                guard !Task.isCancelled, !pointerState.isInside else { return }
                hoverReady = false
            }
            return
        }

        let delay = NotchPreferences.clampedHoverDelay(hoverDelay)
        hoverTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int64(delay * 1_000)))
            guard !Task.isCancelled, pointerState.isInside else { return }
            hoverReady = true
        }
    }

    private func handleTrackChange(from oldValue: String?, to newValue: String?) {
        guard
            notificationsEnabled,
            oldValue != nil,
            newValue != nil,
            oldValue != newValue
        else {
            return
        }

        notificationTask?.cancel()
        notificationVisible = true

        let duration = NotchPreferences.clampedNotificationDuration(notificationDuration)
        notificationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int64(duration * 1_000)))
            guard !Task.isCancelled else { return }
            notificationVisible = false
        }
    }
}
