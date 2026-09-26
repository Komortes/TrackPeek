import Foundation
import Testing
@testable import TrackPeek

@Suite("Lyrics reader navigation")
struct LyricsReaderNavigationTests {
    @Test("clicking a line inverts the lyric offset and adds a rounding margin",
          arguments: [(-3.0, 23.001), (0.0, 20.001), (3.0, 17.001)])
    func seekRespectsOffset(_ values: (offset: Double, expected: Double)) throws {
        let position = try #require(LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: 20, text: "Selected line"), duration: 100, offset: values.offset
        ))
        #expect(abs(position - values.expected) < 0.000_001)
    }

    @Test("seek offsets are bounded to ten seconds",
          arguments: [(-90.0, 30.001), (90.0, 10.001)])
    func seekClampsOffset(_ values: (offset: Double, expected: Double)) throws {
        let position = try #require(LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: 20, text: "Selected line"), duration: 100, offset: values.offset
        ))
        #expect(abs(position - values.expected) < 0.000_001)
    }

    @Test("lines shifted before the track start cannot seek to a negative time")
    func seekClampsBeforeStart() throws {
        let position = try #require(LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: 2, text: "Opening"), duration: 100, offset: 5
        ))
        #expect(position == 0)
    }

    @Test("a lyric exactly at the track start receives the rounding margin")
    func seekAtStart() throws {
        let position = try #require(LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: 2, text: "Opening"), duration: 100, offset: 2
        ))
        #expect(abs(position - 0.001) < 0.000_001)
    }

    @Test("exact end is valid and the rounding margin never passes the end")
    func seekRespectsTrackEnd() throws {
        let exactEnd = LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: 10, text: "End"), duration: 10, offset: 0
        )
        #expect(exactEnd == 10)
        let nearEnd = try #require(LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: 9.9995, text: "Almost finished"), duration: 10, offset: 0
        ))
        #expect(nearEnd == 10)
    }

    @Test("a line beyond the playback duration is not redirected to the song ending",
          arguments: [(11.0, 0.0), (9.0, -2.0)])
    func rejectsTargetsBeyondEnd(_ values: (time: Double, offset: Double)) {
        #expect(LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: values.time, text: "Outside track"), duration: 10, offset: values.offset
        ) == nil)
    }

    @Test("instrumental gaps and whitespace rows are not seek targets", arguments: ["", " ", "\t\n "])
    func rejectsEmptyLyrics(_ text: String) {
        #expect(LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: 10, text: text), duration: 100, offset: 0
        ) == nil)
    }

    @Test("invalid duration cannot produce a seek target",
          arguments: [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity])
    func rejectsInvalidDuration(_ duration: Double) {
        #expect(LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: 10, text: "Line"), duration: duration, offset: 0
        ) == nil)
    }

    @Test("invalid lyric timestamps cannot produce a seek target",
          arguments: [-1.0, Double.nan, Double.infinity, -Double.infinity])
    func rejectsInvalidTimestamp(_ time: Double) {
        #expect(LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: time, text: "Line"), duration: 100, offset: -5
        ) == nil)
    }

    @Test("nonfinite offsets are rejected before clamping",
          arguments: [Double.nan, Double.infinity, -Double.infinity])
    func rejectsInvalidOffset(_ offset: Double) {
        #expect(LyricsReaderNavigation.seekPosition(
            for: LyricsLine(time: 10, text: "Line"), duration: 100, offset: offset
        ) == nil)
    }

    @Test("seeking a paused track immediately resolves the selected lyric",
          arguments: [-10.0, -3.7, 0.0, 2.3, 10.0])
    func seekAndCurrentIndexAreInverses(_ offset: Double) throws {
        let lines = [
            LyricsLine(time: 5.5, text: "First"),
            LyricsLine(time: 10.2, text: "Selected"),
            LyricsLine(time: 20, text: "Last"),
        ]
        let position = try #require(LyricsReaderNavigation.seekPosition(
            for: lines[1], duration: 100, offset: offset
        ))
        // A paused player does not advance past the boundary by itself. Model
        // tiny serialization rounding in addition to undoing the lyric offset.
        #expect(TrackLyrics.currentIndex(in: lines, position: position + offset - 0.000_001) == 1)
    }

    @Test("an empty reader has no scroll target")
    func emptyScrollTarget() {
        #expect(LyricsReaderNavigation.currentScrollIndex(in: [], position: 0) == nil)
    }

    @Test("scrolling follows exact boundaries including instrumental gaps")
    func scrollTargetsBoundariesAndGaps() {
        let lines = [
            LyricsLine(time: 5, text: "First"),
            LyricsLine(time: 10, text: ""),
            LyricsLine(time: 20, text: "Last"),
        ]
        #expect(LyricsReaderNavigation.currentScrollIndex(in: lines, position: 0) == 0)
        #expect(LyricsReaderNavigation.currentScrollIndex(in: lines, position: 5) == 0)
        #expect(LyricsReaderNavigation.currentScrollIndex(in: lines, position: 9.999) == 0)
        #expect(LyricsReaderNavigation.currentScrollIndex(in: lines, position: 10) == 1)
        #expect(LyricsReaderNavigation.currentScrollIndex(in: lines, position: 19) == 1)
        #expect(LyricsReaderNavigation.currentScrollIndex(in: lines, position: 20) == 2)
        #expect(LyricsReaderNavigation.currentScrollIndex(in: lines, position: 500) == 2)
    }

    @Test("backward seeking returns to earlier scroll rows")
    func backwardScrollTargets() {
        let lines = [
            LyricsLine(time: 5, text: "First"),
            LyricsLine(time: 10, text: "Middle"),
            LyricsLine(time: 20, text: "Last"),
        ]
        let targets = [21.0, 12, 6, 0].map {
            LyricsReaderNavigation.currentScrollIndex(in: lines, position: $0)
        }
        #expect(targets == [2, 1, 0, 0])
    }
}
