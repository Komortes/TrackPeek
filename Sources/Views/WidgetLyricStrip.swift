import SwiftUI

struct WidgetLyricStrip: View {
    let context: WidgetCardContext
    let track: SpotifyTrack
    let isHovering: Bool
    let isVisible: Bool
    @FocusState private var isFocused: Bool
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        let state = context.lyricsStore.state(for: track)
        let now = Date()
        let lines: [LyricsLine] = if case .loaded(let lyrics) = state, lyrics.isSynced { lyrics.syncedLines } else { [] }
        let dates = LyricStripTimeline.dates(lines: lines, position: track.position,
            snapshotDate: context.model.snapshotDate, duration: track.duration,
            isPlaying: track.isPlaying, isVisible: isVisible, isStale: context.model.isStale, now: now, offset: context.lyricsStore.offset(for: track))
        Group {
            if dates.isEmpty {
                content(state: state, at: now)
            } else {
                TimelineView(.explicit(dates)) { timeline in
                    content(state: state, at: timeline.date)
                }
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(keys: [.space, .leftArrow, .rightArrow], phases: .down) { press in
            guard PlaybackKeyboardInput.accepts(press.modifiers) else { return .ignored }
            switch press.key {
            case .space: Task { await context.model.togglePlayback() }
            case .leftArrow: Task { await context.model.previousTrack() }
            case .rightArrow: Task { await context.model.nextTrack() }
            default: return .ignored
            }
            return .handled
        }
    }

    private func content(state: LyricsStore.State, at date: Date) -> some View {
        let position = PlaybackPositionResolver.livePosition(snapshotPosition: track.position,
            snapshotDate: context.model.snapshotDate, now: date, duration: track.duration,
            isPlaying: track.isPlaying && !context.model.isStale)
        return LyricStripContent(
            presentation: LyricStripPresentation.resolve(state: state, position: position + context.lyricsStore.offset(for: track), title: track.title, artist: track.artist),
            isPlaying: track.isPlaying, showsControls: isHovering || isFocused || controlActiveState == .key || voiceOverEnabled,
            onPrevious: { Task { await context.model.previousTrack() } },
            onPlayPause: { Task { await context.model.togglePlayback() } },
            onNext: { Task { await context.model.nextTrack() } },
            onRetry: { context.lyricsStore.retry(for: track) }
        )
    }
}

/// The text never reflows when controls appear: they cover only the trailing edge.
struct LyricStripContent: View {
    let presentation: LyricStripPresentation
    let isPlaying: Bool
    let showsControls: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onRetry: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 9) {
            if let symbol = presentation.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .help(presentation.status ?? "")
                    .accessibilityLabel(presentation.status ?? "")
            }
            Text(presentation.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(presentation.text)
                .transition(.opacity)
                .help([presentation.text, presentation.status].compactMap { $0 }.joined(separator: "\n"))
            if presentation.canRetry && !showsControls { retryButton }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            if showsControls {
                HStack(spacing: 8) {
                    if presentation.canRetry { retryButton }
                    PlaybackControlsView(isPlaying: isPlaying, onPrevious: onPrevious,
                        onPlayPause: onPlayPause, onNext: onNext, spacing: 6, compact: true)
                        .tint(.white)
                }
                .padding(.leading, 26).padding(.trailing, 12)
                .frame(maxHeight: .infinity)
                .background {
                    LinearGradient(stops: [.init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.96), location: 0.2), .init(color: .black.opacity(0.96), location: 1)],
                        startPoint: .leading, endPoint: .trailing)
                }
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: presentation.text)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: showsControls)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(isPlaying ? "Пауза" : "Воспроизвести"), onPlayPause)
        .accessibilityAction(named: Text("Предыдущий трек"), onPrevious)
        .accessibilityAction(named: Text("Следующий трек"), onNext)
    }

    private var retryButton: some View {
        Button(action: onRetry) { Image(systemName: "arrow.clockwise").frame(width: 24, height: 28) }
            .buttonStyle(.plain).foregroundStyle(.white.opacity(0.8))
            .help("Повторить поиск текста").accessibilityLabel("Повторить поиск текста")
    }
}

struct WidgetLyricStripUnavailable: View {
    let model: SpotifySpikeModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note").foregroundStyle(.secondary)
            Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading).help(title)
            if model.availability != .loading {
                Button(actionTitle) {
                    if model.availability == .spotifyNotRunning || model.availability == .nothingPlaying {
                        PlayerAppLauncher.openActiveSource()
                    } else { Task { await model.refresh() } }
                }
                .buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
            }
        }
        .padding(.horizontal, 18).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionTitle: String {
        model.availability == .spotifyNotRunning || model.availability == .nothingPlaying ? "Открыть плеер" : "Повторить"
    }

    private var title: String {
        switch model.availability {
        case .loading: "Обновляем трек…"
        case .ready, .nothingPlaying: "Выберите трек в \(model.activeSourceDisplayName)"
        case .spotifyNotRunning: "\(model.activeSourceDisplayName) не запущен"
        case .automationDenied: "Нет доступа к плееру"
        case .unavailable: "Плеер временно недоступен"
        }
    }
}
