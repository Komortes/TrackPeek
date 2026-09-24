import AppKit
import SwiftUI
import Testing
@testable import TrackPeek

@MainActor
@Suite("Lyric strip")
struct LyricStripTests {
    private let lines = [LyricsLine(time: 5, text: "First line"), LyricsLine(time: 12, text: "Second line"), LyricsLine(time: 22, text: "Third line")]
    private let snapshot = Date(timeIntervalSince1970: 1_000)

    @Test func timelineWakesOnlyAtFutureLyrics() {
        let now = snapshot.addingTimeInterval(3)
        let dates = LyricStripTimeline.dates(lines: lines, position: 6, snapshotDate: snapshot,
            duration: 60, isPlaying: true, isVisible: true, isStale: false, now: now)
        #expect(dates == [now, snapshot.addingTimeInterval(6.001), snapshot.addingTimeInterval(16.001)])
    }

    @Test func timelineStopsWhenPausedHiddenOrStale() {
        for (playing, visible, stale) in [(false, true, false), (true, false, false), (true, true, true)] {
            #expect(LyricStripTimeline.dates(lines: lines, position: 6, snapshotDate: snapshot,
                duration: 60, isPlaying: playing, isVisible: visible, isStale: stale, now: snapshot).isEmpty)
        }
    }

    @Test func seekRebuildsScheduleAndDuplicateTimesDoNotRepeatWakeups() {
        let duplicate = lines + [LyricsLine(time: 12, text: "Same time"), LyricsLine(time: 120, text: "Past end")]
        let forward = LyricStripTimeline.dates(lines: duplicate, position: 15, snapshotDate: snapshot,
            duration: 60, isPlaying: true, isVisible: true, isStale: false, now: snapshot)
        #expect(forward == [snapshot, snapshot.addingTimeInterval(7.001)])
        let backward = LyricStripTimeline.dates(lines: duplicate, position: 0, snapshotDate: snapshot,
            duration: 60, isPlaying: true, isVisible: true, isStale: false, now: snapshot)
        #expect(backward == [snapshot, snapshot.addingTimeInterval(5.001), snapshot.addingTimeInterval(12.001), snapshot.addingTimeInterval(22.001)])
    }

    @Test func fractionalBoundariesResolveToTheNewLine() {
        // Date rounds relative to its reference epoch. A deadline must not land
        // just before the LRC timestamp and leave the old line until the next poll.
        let start = Date(timeIntervalSince1970: 1_000.1234567)
        for time in [0.25, 1.001, 5.12, 11.999] {
            let dates = LyricStripTimeline.dates(lines: [.init(time: time, text: "New")], position: 0.15,
                snapshotDate: start, duration: 60, isPlaying: true, isVisible: true,
                isStale: false, now: start.addingTimeInterval(0.001))
            let live = PlaybackPositionResolver.livePosition(snapshotPosition: 0.15, snapshotDate: start,
                now: dates.last!, duration: 60, isPlaying: true)
            #expect(live >= time)
        }
    }

    @Test func fallbackDoesNotDisplayUnsyncedOrPreviousLyrics() {
        for state: LyricsStore.State in [.loading, .unavailable, .failed, .loaded(.init(syncedLines: [], plainText: "A full unsynced text"))] {
            let content = LyricStripPresentation.resolve(state: state, position: 10, title: "New track", artist: "New artist")
            #expect(content.text == "New track — New artist")
            #expect(content.canRetry == (state == .failed))
        }
        let synced = LyricsStore.State.loaded(.init(syncedLines: lines, plainText: nil))
        #expect(LyricStripPresentation.resolve(state: synced, position: 1, title: "Intro", artist: "Artist").text == "Intro — Artist")
        #expect(LyricStripPresentation.resolve(state: synced, position: 12, title: "Track", artist: "Artist").text == "Second line")
        #expect(LyricStripPresentation.resolve(state: synced, position: 6, title: "Track", artist: "Artist").text == "First line")
    }

    @Test func dimensionsStayCompactAcrossLayoutsAndWidths() {
        #expect(NotchWidgetLayout.lyricStrip.family == .lyrics)
        #expect(NotchWidgetLayout.lyricStrip.isAlwaysExpanded)
        #expect(WidgetPreferences.cardSize(layout: .lyricStrip, width: 240, heightAdjustment: 100) == CGSize(width: 320, height: 56))
        #expect(WidgetPreferences.cardSize(layout: .lyricStrip, width: 420, heightAdjustment: -20) == CGSize(width: 500, height: 56))
    }

    @Test func rendersStatesAtMinimumWidthWithoutChangingHeight() throws {
        let states: [LyricsStore.State] = [
            .loaded(.init(syncedLines: [.init(time: 0, text: "A line that stays with you")], plainText: nil)),
            .loaded(.init(syncedLines: [.init(time: 0, text: "Очень длинная строка песни, которая должна обрезаться и открываться полностью в подсказке")], plainText: nil)),
            .loading, .failed, .unavailable
        ]
        let content = VStack(spacing: 16) {
            ForEach(Array(states.enumerated()), id: \.offset) { index, state in
                LyricStripContent(
                    presentation: LyricStripPresentation.resolve(state: state, position: 10, title: "Current track", artist: "Artist"),
                    isPlaying: false, showsControls: index == 1, onPrevious: {}, onPlayPause: {}, onNext: {}, onRetry: {}
                )
                .frame(width: 320, height: 56)
                .background(Color.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 16))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(24).background(Color(red: 0.14, green: 0.17, blue: 0.20))
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width == 736)
        #expect(image.height == 784)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("trackpeek-lyric-strip.png"))
    }
}
