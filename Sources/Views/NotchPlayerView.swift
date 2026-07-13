import AppKit
import SwiftUI

struct NotchPlayerView: View {
    let model: SpotifySpikeModel
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
    @State private var isHovering = false
    @State private var isPinned = false
    @State private var notificationVisible = false
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
        Group {
            if isExpanded {
                expandedContent
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity
                        )
                    )
            } else {
                compactContent
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: isExpanded ? 22 : 12,
                bottomTrailingRadius: isExpanded ? 22 : 12,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.black.opacity(0.97))
            .shadow(color: .black.opacity(isExpanded ? 0.34 : 0.2), radius: 18, y: 8)
        }
        .overlay(alignment: .bottom) {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: isExpanded ? 22 : 12,
                bottomTrailingRadius: isExpanded ? 22 : 12,
                topTrailingRadius: 0,
                style: .continuous
            )
            .stroke(.white.opacity(isExpanded ? 0.1 : 0.06), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .environment(\.colorScheme, .dark)
        .animation(
            reduceMotion ? nil : .spring(duration: 0.34, bounce: 0.12),
            value: isExpanded
        )
        .onHover(perform: handleHover)
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
        .onAppear {
            onExpansionChange(false)
        }
        .onDisappear {
            hoverTask?.cancel()
            notificationTask?.cancel()
        }
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
                    Text(track.title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                } else {
                    Spacer(minLength: 0)
                }

                NotchWaveformView(
                    isPlaying: track.isPlaying,
                    isColored: coloredWaveform
                )
                .frame(width: 25)
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
            VStack(spacing: 11) {
                HStack(spacing: 12) {
                    TrackArtworkView(
                        url: track.artworkURL,
                        size: 58,
                        cornerRadius: 11,
                        showsShadow: true
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let album = track.album, !album.isEmpty {
                            Text(album)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    NotchWaveformView(
                        isPlaying: track.isPlaying,
                        isColored: coloredWaveform
                    )

                    Button {
                        isPinned = false
                        notificationVisible = false
                        hoverReady = false
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Свернуть плеер")
                }

                PlaybackProgressView(
                    position: track.position,
                    duration: track.duration,
                    isPlaying: track.isPlaying,
                    snapshotDate: model.snapshotDate,
                    onSeek: model.seek(to:),
                    tint: coloredProgress ? .cyan : .white
                )

                PlaybackControlsView(
                    isPlaying: track.isPlaying,
                    onPrevious: model.previousTrack,
                    onPlayPause: model.togglePlayback,
                    onNext: model.nextTrack,
                    spacing: 24
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 14)
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
        isHovering = hovering
        hoverTask?.cancel()

        guard hoverEnabled else {
            hoverReady = false
            return
        }

        guard hovering else {
            hoverReady = false
            return
        }

        let delay = NotchPreferences.clampedHoverDelay(hoverDelay)
        hoverTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int64(delay * 1_000)))
            guard !Task.isCancelled, isHovering else { return }
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

private struct NotchWaveformView: View {
    let isPlaying: Bool
    let isColored: Bool

    @State private var pulses = false

    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isColored ? Color.cyan : Color.white.opacity(0.72))
            .scaleEffect(y: isPlaying && pulses ? 1 : 0.7)
            .opacity(isPlaying ? 1 : 0.58)
            .animation(
                isPlaying
                    ? .easeInOut(duration: 0.52).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.18),
                value: pulses
            )
            .onAppear {
                pulses = true
            }
            .accessibilityHidden(true)
    }
}
