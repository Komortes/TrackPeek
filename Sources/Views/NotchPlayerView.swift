import AppKit
import SwiftUI

struct NotchPlayerView: View {
    let model: SpotifySpikeModel
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hoverReady = false
    @State private var isPinned = false
    @State private var notificationVisible = false
    @State private var artworkPalette = ArtworkPalette.fallback
    @State private var hoverTask: Task<Void, Never>?
    @State private var notificationTask: Task<Void, Never>?

    private var songInfoVisibility: NotchSongInfoVisibility {
        NotchSongInfoVisibility(rawValue: songInfoVisibilityRawValue) ?? .fallback
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
        ZStack {
            compactContent
                .opacity(isExpanded ? 0 : 1)
                .offset(y: isExpanded ? -3 : 0)
                .allowsHitTesting(!isExpanded)

            expandedContent
                .opacity(isExpanded ? 1 : 0)
                .offset(y: isExpanded ? 0 : -4)
                .allowsHitTesting(isExpanded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            notchBackground
        }
        .clipShape(notchShape)
        .contentShape(Rectangle())
        .environment(\.colorScheme, .dark)
        .animation(
            reduceMotion
                ? nil
                : .timingCurve(0.23, 1, 0.32, 1, duration: NotchMotion.contentDuration),
            value: isExpanded
        )
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
        .task(id: model.track?.artworkURL) {
            artworkPalette = .fallback
            artworkPalette = await ArtworkPaletteLoader.shared.palette(
                for: model.track?.artworkURL
            )
        }
        .onAppear {
            onExpansionChange(false)
            handleHover(pointerState.isInside)
        }
        .onDisappear {
            hoverTask?.cancel()
            notificationTask?.cancel()
        }
    }

    private var notchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: isExpanded ? 22 : 12,
            bottomTrailingRadius: isExpanded ? 22 : 12,
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
            reduceMotion ? nil : .easeOut(duration: 0.28),
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
                    isPlaying: track.isPlaying,
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
    private var expandedContent: some View {
        if let track = model.track, model.availability == .ready {
            HStack(alignment: .center, spacing: 15) {
                VStack(spacing: 7) {
                    TrackArtworkView(
                        url: track.artworkURL,
                        size: 78,
                        cornerRadius: 15,
                        showsShadow: true
                    )

                    HStack(spacing: 5) {
                        Circle()
                            .fill(track.isPlaying ? artworkPalette.primary.swiftUIColor : .secondary)
                            .frame(width: 5, height: 5)

                        Text(track.isPlaying ? "ИГРАЕТ" : "ПАУЗА")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(0.7)
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(width: 82)

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

                            if let album = track.album, !album.isEmpty {
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
                        onSeek: model.seek(to:),
                        tint: coloredProgress ? artworkPalette.primary.swiftUIColor : .white
                    )

                    Spacer(minLength: 4)

                    HStack(spacing: 12) {
                        PlaybackControlsView(
                            isPlaying: track.isPlaying,
                            onPrevious: model.previousTrack,
                            onPlayPause: model.togglePlayback,
                            onNext: model.nextTrack,
                            spacing: 10
                        )
                        .tint(artworkPalette.primary.swiftUIColor)

                        Spacer(minLength: 8)

                        ArtworkEqualizerView(
                            isPlaying: track.isPlaying,
                            isColored: coloredWaveform,
                            palette: artworkPalette
                        )
                        .frame(width: 48, height: 24)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 13)
            .padding(.bottom, 12)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(model.statusText)
                    .font(.callout.weight(.medium))

                Button("Обновить", action: model.refresh)
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)
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
