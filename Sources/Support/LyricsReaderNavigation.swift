import Foundation

enum LyricsReaderNavigation {
    static func seekPosition(for line: LyricsLine, duration: TimeInterval, offset: TimeInterval) -> TimeInterval? {
        guard !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              line.time.isFinite, line.time >= 0, duration.isFinite, duration > 0, offset.isFinite else { return nil }
        let position = line.time - min(max(offset, -10), 10)
        guard position <= duration else { return nil }
        if position < 0 { return 0 }
        // Resolve the clicked line even when Date arithmetic rounds its boundary.
        return min(position + 0.001, duration)
    }

    static func currentScrollIndex(in lines: [LyricsLine], position: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        return TrackLyrics.currentIndex(in: lines, position: position) ?? 0
    }
}
