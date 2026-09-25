import Foundation

/// Explicit lyric boundaries instead of a display-link or periodic timer.
enum LyricStripTimeline {
    static func dates(lines: [LyricsLine], position: TimeInterval, snapshotDate: Date,
                      duration: TimeInterval, isPlaying: Bool, isVisible: Bool,
                      isStale: Bool, now: Date, offset: TimeInterval = 0) -> [Date] {
        guard isPlaying, isVisible, !isStale, !lines.isEmpty,
              position.isFinite, duration.isFinite, duration > 0 else { return [] }
        let livePosition = PlaybackPositionResolver.livePosition(snapshotPosition: position,
            snapshotDate: snapshotDate, now: now, duration: duration, isPlaying: true)
        let adjustment = offset.isFinite ? min(max(offset, -10), 10) : 0
        let remainingTimes = Set(lines.lazy.map { $0.time - adjustment }.filter {
            $0.isFinite && $0 > livePosition && $0 <= duration
        })
        // A tiny positive offset prevents Date rounding from resolving the previous
        // line at the exact boundary. This is below visible timing precision.
        return [now] + remainingTimes.sorted().map { now.addingTimeInterval($0 - livePosition + 0.001) }
    }
}

struct LyricStripPresentation: Equatable {
    let text: String
    let status: String?
    let symbol: String?
    let canRetry: Bool

    static func resolve(state: LyricsStore.State, position: TimeInterval,
                        title: String, artist: String) -> Self {
        let metadata = "\(title) — \(artist)"
        switch state {
        case .loaded(let lyrics):
            if lyrics.isSynced, let index = TrackLyrics.currentIndex(in: lyrics.syncedLines, position: position) {
                let text = lyrics.syncedLines[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty
                    ? Self(text: metadata, status: "Проигрыш", symbol: "music.note", canRetry: false)
                    : Self(text: text, status: nil, symbol: nil, canRetry: false)
            }
            return Self(text: metadata, status: lyrics.isSynced ? "Ждём первую строку" : "Нет синхронизированного текста",
                        symbol: "music.note", canRetry: false)
        case .loading:
            return Self(text: metadata, status: "Ищем текст…", symbol: "ellipsis", canRetry: false)
        case .unavailable:
            return Self(text: metadata, status: "Текст не найден", symbol: "music.note", canRetry: true)
        case .failed:
            return Self(text: metadata, status: "Не удалось загрузить текст", symbol: "wifi.exclamationmark", canRetry: true)
        }
    }
}
