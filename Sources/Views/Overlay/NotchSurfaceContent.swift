import AppKit
import SwiftUI

/// Содержимое чёлки: компактная полоска, лёгкое уведомление о новом треке и
/// полностью раскрытый плеер. Отделено от `NotchPlayerView`, чтобы оно не
/// знало о существовании виджета и не читало `@AppStorage` напрямую — все
/// нужные настройки приходят одним `OverlayAppearance`.
struct NotchSurfaceContent: View {
    let model: SpotifySpikeModel
    let audioMonitor: SpotifyAudioMonitor
    let lyricsStore: LyricsStore
    let appearance: OverlayAppearance
    let palette: ArtworkPalette
    let panelState: NotchPanelState
    let containerSize: CGSize
    let revealProgress: Double
    let songInfoVisibility: NotchSongInfoVisibility
    let clickEnabled: Bool
    let onTogglePin: () -> Void
    let onCollapse: () -> Void
    /// Второстепенные контролы (shuffle/repeat/громкость) — только когда это
    /// содержимое переиспользуется под карточную раскладку виджета
    /// (`cardHorizontal`), не в самой чёлке.
    var showsSecondaryControls = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isExpanded: Bool { panelState == .expanded }

    var body: some View {
        ZStack(alignment: .top) {
            compactContent
                .frame(
                    maxWidth: .infinity,
                    minHeight: min(containerSize.height, 44),
                    maxHeight: min(containerSize.height, 44)
                )
                .opacity(
                    panelState == .notification
                        ? 0
                        : max(0, 1 - revealProgress * 1.35)
                )
                .scaleEffect(1 - revealProgress * 0.015, anchor: .top)
                .allowsHitTesting(panelState == .collapsed)

            if panelState == .notification {
                notificationContent
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                    )
            }

            expandedContent
                .opacity(revealProgress)
                .scaleEffect(0.985 + revealProgress * 0.015, anchor: .top)
                .allowsHitTesting(isExpanded && revealProgress > 0.8)
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .top)
    }

    /// Лёгкое уведомление о новом треке: обложка и название без контролов.
    @ViewBuilder
    private var notificationContent: some View {
        if let track = model.track {
            HStack(spacing: 12) {
                TrackArtworkView(
                    url: track.artworkURL,
                    size: 40,
                    cornerRadius: 8,
                    showsShadow: false
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ArtworkEqualizerView(
                    audioMonitor: audioMonitor,
                    isPlaying: track.isPlaying,
                    isVisible: panelState == .notification,
                    isColored: appearance.coloredWaveform,
                    palette: palette,
                    sensitivityOverride: appearance.equalizerSensitivityOverride
                )
                .frame(width: 28, height: 18)
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Новый трек: \(track.title), \(track.artist)")
        }
    }

    @ViewBuilder
    private var compactContent: some View {
        if let track = model.track, model.availability == .ready {
            HStack(spacing: 10) {
                TrackArtworkView(
                    url: track.artworkURL,
                    size: NotchResponsiveLayout.compactArtworkSize,
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
                    isColored: appearance.coloredWaveform,
                    palette: palette
                )
                .frame(
                    width: NotchResponsiveLayout.compactEqualizerSize.width,
                    height: NotchResponsiveLayout.compactEqualizerSize.height
                )
                .offset(y: NotchResponsiveLayout.compactEqualizerVerticalOffset)
            }
            .padding(.horizontal, NotchResponsiveLayout.compactHorizontalPadding)
            .onTapGesture {
                guard clickEnabled else { return }
                onTogglePin()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Компактный плеер TrackPeek")
            .accessibilityHint("Раскрывает элементы управления воспроизведением")
            .accessibilityAction {
                guard clickEnabled else { return }
                onTogglePin()
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

    private struct ExpandedContentState: Equatable {
        let availability: PlaybackAvailability
        let hasTrack: Bool
    }

    @ViewBuilder
    private var expandedContent: some View {
        Group {
            expandedContentBody
        }
        .animation(
            reduceMotion
                ? nil
                : .smooth(duration: PlayerMotion.playbackDuration, extraBounce: 0),
            value: ExpandedContentState(
                availability: model.availability,
                hasTrack: model.track != nil
            )
        )
    }

    @ViewBuilder
    private var expandedContentBody: some View {
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
                    .contentShape(Rectangle())
                    .onTapGesture { PlayerAppLauncher.openActiveSource() }
                    .help("Открыть плеер")

                    HStack(spacing: 5) {
                        Circle()
                            .fill(track.isPlaying ? palette.primary.onDarkSurface.swiftUIColor : .secondary)
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
                            appearance.lyricsEnabled.wrappedValue.toggle()
                        } label: {
                            Image(
                                systemName: appearance.lyricsEnabled.wrappedValue
                                    ? "quote.bubble.fill"
                                    : "quote.bubble"
                            )
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 22, height: 22)
                            .background(.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            appearance.lyricsEnabled.wrappedValue
                                ? AnyShapeStyle(palette.primary.onDarkSurface.swiftUIColor)
                                : AnyShapeStyle(.secondary)
                        )
                        .help(
                            appearance.lyricsEnabled.wrappedValue
                                ? "Скрыть текст песни"
                                : "Показать текст песни"
                        )

                        Button(action: onCollapse) {
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

                    if appearance.lyricsEnabled.wrappedValue {
                        NotchLyricsView(
                            state: lyricsStore.state(for: track),
                            position: track.position,
                            duration: track.duration,
                            isPlaying: track.isPlaying,
                            snapshotDate: model.snapshotDate,
                            tint: appearance.coloredProgress
                                ? palette.primary.onDarkSurface.swiftUIColor
                                : .white
                        )
                    } else {
                        PlaybackProgressView(
                            position: track.position,
                            duration: track.duration,
                            isPlaying: track.isPlaying,
                            snapshotDate: model.snapshotDate,
                            onSeek: { position in Task { await model.seek(to: position) } },
                            tint: appearance.coloredProgress
                                ? palette.primary.onDarkSurface.swiftUIColor
                                : .white
                        )
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: 12) {
                        PlaybackControlsView(
                            isPlaying: track.isPlaying,
                            onPrevious: { Task { await model.previousTrack() } },
                            onPlayPause: { Task { await model.togglePlayback() } },
                            onNext: { Task { await model.nextTrack() } },
                            spacing: isNarrow ? 7 : 10
                        )
                        .tint(palette.primary.onDarkSurface.swiftUIColor)

                        Spacer(minLength: 8)

                        ArtworkEqualizerView(
                            audioMonitor: audioMonitor,
                            isPlaying: track.isPlaying,
                            isVisible: isExpanded,
                            isColored: appearance.coloredWaveform,
                            palette: palette,
                            sensitivityOverride: appearance.equalizerSensitivityOverride
                        )
                        .frame(width: isNarrow ? 36 : 48, height: 24)
                    }

                    if showsSecondaryControls,
                       !model.capabilities.isDisjoint(with: [.shuffle, .repeatTrack, .volume]) {
                        SecondaryControlsView(
                            capabilities: model.capabilities,
                            secondary: model.secondary,
                            onShuffle: { enabled in Task { await model.setShuffle(enabled) } },
                            onRepeat: { mode in Task { await model.setRepeat(mode) } },
                            onVolume: { volume in Task { await model.setVolume(volume) } }
                        )
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
            PlayerStateView(availability: model.availability, sourceName: model.activeSourceDisplayName) {
                Task { await model.refresh() }
            }
            .padding(20)
            .transition(
                .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
            )
        }
    }
}
