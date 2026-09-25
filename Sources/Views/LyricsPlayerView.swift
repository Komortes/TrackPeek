import SwiftUI

/// A bounded reading window for synchronized text; plain text scrolls only by user input.
struct LyricsReadingWindow {
    struct Entry: Equatable, Identifiable {
        let index: Int
        let text: String
        let isCurrent: Bool
        var id: Int { index }
    }
    static func entries(in lines: [LyricsLine], position: TimeInterval) -> [Entry] {
        let current = TrackLyrics.currentIndex(in: lines, position: position) ?? -1
        let start = max(0, current - 1)
        return (start..<min(lines.count, start + 4)).map {
            Entry(index: $0, text: lines[$0].text, isCurrent: $0 == current)
        }
    }
}

struct LyricsPlayerView: View {
    let model: SpotifySpikeModel
    let track: SpotifyTrack
    let lyricsStore: LyricsStore
    let options: PlayerPresentationOptions
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 10) {
            PlayerHeaderView(track: track, sourceName: model.activeSourceDisplayName,
                showsPlaybackStatus: options.showsPlaybackStatus, onRefresh: { Task { await model.refresh() } })
            TrackInfoView(track: track, showsAlbum: options.showsAlbum, titleLineLimit: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
            readingArea.frame(maxWidth: .infinity, maxHeight: .infinity)
            PlaybackProgressView(position: track.position, duration: track.duration,
                isPlaying: track.isPlaying && isVisible && !model.isStale, snapshotDate: model.snapshotDate,
                onSeek: { position in Task { await model.seek(to: position) } }, minimumUpdateInterval: 0.25)
            PlaybackControlsView(isPlaying: track.isPlaying,
                onPrevious: { Task { await model.previousTrack() } },
                onPlayPause: { Task { await model.togglePlayback() } },
                onNext: { Task { await model.nextTrack() } }, spacing: 24)
        }
        .padding(16)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task(id: RequestKey(request: LyricsRequest(track: track), visible: isVisible)) {
            guard isVisible else { return }
            lyricsStore.prepare(for: track)
        }
    }

    private struct RequestKey: Equatable {
        let request: LyricsRequest
        let visible: Bool
    }

    @ViewBuilder private var readingArea: some View {
        switch lyricsStore.state(for: track) {
        case .loading:
            placeholder("Ищем текст…", symbol: "text.quote")
        case .unavailable, .failed:
            VStack(spacing: 12) {
                placeholder(lyricsStore.state(for: track) == .unavailable ? "Текст не найден" : "Не удалось загрузить текст", symbol: "quote.bubble")
                Button("Повторить поиск") { lyricsStore.retry(for: track) }.buttonStyle(.bordered)
            }
        case .loaded(let lyrics):
            if lyrics.isSynced {
                let now = Date()
                let dates = LyricStripTimeline.dates(lines: lyrics.syncedLines, position: track.position,
                    snapshotDate: model.snapshotDate, duration: track.duration, isPlaying: track.isPlaying,
                    isVisible: isVisible, isStale: model.isStale, now: now, offset: lyricsStore.offset(for: track))
                if dates.isEmpty {
                    synced(lyrics.syncedLines, at: now)
                } else {
                    TimelineView(.explicit(dates)) { timeline in synced(lyrics.syncedLines, at: timeline.date) }
                }
            } else if let plain = lyrics.plainText, !plain.isEmpty {
                ScrollView {
                    Text(plain).font(.system(size: 15)).lineSpacing(6)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(LyricsRequest(track: track))
            } else {
                placeholder("Текст не найден", symbol: "quote.bubble")
            }
        }
    }

    private func synced(_ lines: [LyricsLine], at date: Date) -> some View {
        let position = PlaybackPositionResolver.livePosition(snapshotPosition: track.position,
            snapshotDate: model.snapshotDate, now: date, duration: track.duration,
            isPlaying: track.isPlaying && !model.isStale)
        return LyricsReadingLines(entries: LyricsReadingWindow.entries(in: lines, position: position + lyricsStore.offset(for: track)))
    }

    private func placeholder(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.system(size: 13)).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }
}

struct LyricsReadingLines: View {
    let entries: [LyricsReadingWindow.Entry]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entries) { entry in
                Text(entry.text.isEmpty ? "Проигрыш" : entry.text)
                    .font(.system(size: entry.isCurrent && !entry.text.isEmpty ? 20 : 14, weight: entry.isCurrent && !entry.text.isEmpty ? .semibold : .regular))
                    .foregroundStyle(entry.isCurrent && !entry.text.isEmpty ? Color.primary : Color.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 46, alignment: .leading)
                    .help(entry.text.isEmpty ? "Проигрыш" : entry.text)
                    .accessibilityLabel(entry.text.isEmpty ? "Проигрыш" : (entry.isCurrent ? "Сейчас: \(entry.text)" : entry.text))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: entries)
    }
}
