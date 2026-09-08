import SwiftUI

/// Общие зависимости карточных раскладок floating-виджета.
struct WidgetCardContext {
    let model: SpotifySpikeModel
    let lyricsStore: LyricsStore
    let audioMonitor: SpotifyAudioMonitor
    let palette: ArtworkPalette
    let coloredProgress: Bool
    let equalizerSensitivity: Double

    var accent: Color {
        palette.primary.onDarkSurface.swiftUIColor
    }

    var progressTint: Color {
        coloredProgress ? accent : .white
    }
}

// MARK: - Обложка сверху

struct WidgetVerticalCard: View {
    let context: WidgetCardContext
    let track: SpotifyTrack
    let size: CGSize
    let lyricsEnabled: Bool

    var body: some View {
        VStack(spacing: 9) {
            TrackArtworkView(
                url: track.artworkURL,
                size: min(size.width * 0.46, 118),
                cornerRadius: 12,
                showsShadow: true
            )
            .onTapGesture { PlayerAppLauncher.openActiveSource() }
            .help("Открыть плеер")

            VStack(spacing: 1) {
                Text(track.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if lyricsEnabled {
                NotchLyricsView(
                    state: context.lyricsStore.state(for: track),
                    position: track.position,
                    duration: track.duration,
                    isPlaying: track.isPlaying,
                    snapshotDate: context.model.snapshotDate,
                    tint: context.progressTint
                )
            } else {
                WidgetProgressView(context: context, track: track)
            }

            WidgetControls(context: context, track: track, spacing: 10, showsSecondaryControls: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Текст песни (компактный боковой плеер с лирикой)

struct WidgetLyricsCard: View {
    let context: WidgetCardContext
    let track: SpotifyTrack

    var body: some View {
        HStack(spacing: 11) {
            TrackArtworkView(
                url: track.artworkURL,
                size: 46,
                cornerRadius: 9,
                showsShadow: false
            )
            .onTapGesture { PlayerAppLauncher.openActiveSource() }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(track.title)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    Text("· \(track.artist)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }

                NotchLyricsView(
                    state: context.lyricsStore.state(for: track),
                    position: track.position,
                    duration: track.duration,
                    isPlaying: track.isPlaying,
                    snapshotDate: context.model.snapshotDate,
                    tint: context.progressTint
                )
            }

            WidgetControls(context: context, track: track, spacing: 6, compact: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Мини-строка

struct WidgetMiniBar: View {
    let context: WidgetCardContext
    let track: SpotifyTrack

    var body: some View {
        HStack(spacing: 10) {
            TrackArtworkView(
                url: track.artworkURL,
                size: 28,
                cornerRadius: 6,
                showsShadow: false
            )
            .onTapGesture { PlayerAppLauncher.openActiveSource() }

            VStack(alignment: .leading, spacing: 0) {
                Text(track.title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ArtworkEqualizerView(
                audioMonitor: context.audioMonitor,
                isPlaying: track.isPlaying,
                isVisible: true,
                isColored: context.coloredProgress,
                palette: context.palette,
                sensitivityOverride: context.equalizerSensitivity
            )
            .frame(width: 22, height: 14)

            WidgetControls(context: context, track: track, spacing: 6, compact: true)
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Квадрат-обложка

struct WidgetArtworkSquare: View {
    let context: WidgetCardContext
    let track: SpotifyTrack
    let size: CGSize
    /// Наведение приходит от NSTrackingArea панели: SwiftUI onHover ненадёжен,
    /// пока фоновое приложение неактивно.
    let isHovering: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            TrackArtworkView(
                url: track.artworkURL,
                size: max(size.width, size.height),
                cornerRadius: 0,
                showsShadow: false
            )
            .onTapGesture { PlayerAppLauncher.openActiveSource() }

            if isHovering {
                VStack(spacing: 6) {
                    Text("\(track.title) · \(track.artist)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(.white)

                    WidgetControls(context: context, track: track, spacing: 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .background {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.72), .black.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.22, extraBounce: 0),
            value: isHovering
        )
    }
}

// MARK: - Караоке

struct WidgetKaraokeCard: View {
    let context: WidgetCardContext
    let track: SpotifyTrack

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TrackArtworkView(
                    url: track.artworkURL,
                    size: 24,
                    cornerRadius: 5,
                    showsShadow: false
                )

                Text("\(track.title) · \(track.artist)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                WidgetControls(context: context, track: track, spacing: 6, compact: true)
            }

            karaokeLines
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var karaokeLines: some View {
        switch context.lyricsStore.state(for: track) {
        case .loading:
            karaokePlaceholder("Ищем текст…")
        case .unavailable:
            karaokePlaceholder("Текст не найден")
        case .loaded(let lyrics):
            if lyrics.isSynced {
                syncedKaraoke(lyrics.syncedLines)
            } else if let plain = lyrics.plainText {
                ScrollView(showsIndicators: false) {
                    Text(plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                karaokePlaceholder("Текст не найден")
            }
        }
    }

    private func karaokePlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func syncedKaraoke(_ lines: [LyricsLine]) -> some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: !track.isPlaying)) { timelineContext in
            let livePosition = PlaybackPositionResolver.livePosition(
                snapshotPosition: track.position,
                snapshotDate: context.model.snapshotDate,
                now: timelineContext.date,
                duration: track.duration,
                isPlaying: track.isPlaying
            )
            let index = TrackLyrics.currentIndex(in: lines, position: livePosition) ?? -1

            VStack(alignment: .leading, spacing: 5) {
                karaokeLine(lines, at: index - 1, style: .past)
                karaokeLine(lines, at: index, style: .current)
                karaokeLine(lines, at: index + 1, style: .next)
                karaokeLine(lines, at: index + 2, style: .later)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.35, extraBounce: 0),
                value: index
            )
        }
    }

    private enum KaraokeLineStyle {
        case past, current, next, later
    }

    @ViewBuilder
    private func karaokeLine(
        _ lines: [LyricsLine],
        at index: Int,
        style: KaraokeLineStyle
    ) -> some View {
        let text = (index >= 0 && index < lines.count) ? lines[index].text : " "

        switch style {
        case .past:
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        case .current:
            Text(text == " " && index < 0 ? "…" : text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(context.progressTint)
                .lineLimit(2)
                .id("current-\(index)")
                .transition(.push(from: .bottom).combined(with: .opacity))
        case .next:
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        case .later:
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

// MARK: - Эквалайзер

struct WidgetEqualizerCard: View {
    let context: WidgetCardContext
    let track: SpotifyTrack

    var body: some View {
        VStack(spacing: 8) {
            ArtworkEqualizerView(
                audioMonitor: context.audioMonitor,
                isPlaying: track.isPlaying,
                isVisible: true,
                isColored: true,
                palette: context.palette,
                barCount: 21,
                sensitivityOverride: context.equalizerSensitivity
            )
            .frame(maxWidth: .infinity)
            .frame(height: 62)

            HStack(spacing: 8) {
                TrackArtworkView(
                    url: track.artworkURL,
                    size: 22,
                    cornerRadius: 5,
                    showsShadow: false
                )

                Text("\(track.title) · \(track.artist)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                WidgetControls(context: context, track: track, spacing: 6, compact: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Общие элементы

/// Компактные кнопки управления для карточек.
struct WidgetControls: View {
    let context: WidgetCardContext
    let track: SpotifyTrack
    var spacing: CGFloat = 8
    var compact = false
    /// Второстепенные контролы (shuffle/repeat/громкость) — только для
    /// просторных карточных раскладок (cardVertical), не для компактных.
    var showsSecondaryControls = false

    var body: some View {
        VStack(spacing: 8) {
            PlaybackControlsView(
                isPlaying: track.isPlaying,
                onPrevious: { Task { await context.model.previousTrack() } },
                onPlayPause: { Task { await context.model.togglePlayback() } },
                onNext: { Task { await context.model.nextTrack() } },
                spacing: spacing,
                compact: compact
            )
            .tint(context.accent)

            if showsSecondaryControls,
               !context.model.capabilities.isDisjoint(with: [.shuffle, .repeatTrack, .volume]) {
                SecondaryControlsView(
                    capabilities: context.model.capabilities,
                    secondary: context.model.secondary,
                    onShuffle: { enabled in Task { await context.model.setShuffle(enabled) } },
                    onRepeat: { mode in Task { await context.model.setRepeat(mode) } },
                    onVolume: { volume in Task { await context.model.setVolume(volume) } }
                )
            }
        }
    }
}

struct WidgetProgressView: View {
    let context: WidgetCardContext
    let track: SpotifyTrack

    var body: some View {
        PlaybackProgressView(
            position: track.position,
            duration: track.duration,
            isPlaying: track.isPlaying,
            snapshotDate: context.model.snapshotDate,
            onSeek: { position in Task { await context.model.seek(to: position) } },
            tint: context.progressTint
        )
    }
}
