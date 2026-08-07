import Foundation
import Testing
@testable import TrackPeek

@Suite("LRC parser")
struct LRCParserTests {
    @Test("parses timestamped lines in order")
    func parsesTimestampedLines() {
        let lines = LRCParser.parse(
            """
            [00:12.00]Первая строка
            [00:05.50]Нулевая строка
            [01:02.250]Вторая строка
            """
        )

        #expect(lines.map(\.text) == ["Нулевая строка", "Первая строка", "Вторая строка"])
        #expect(lines[0].time == 5.5)
        #expect(lines[1].time == 12)
        #expect(lines[2].time == 62.25)
    }

    @Test("supports repeated timestamps on one line")
    func supportsRepeatedTimestamps() {
        let lines = LRCParser.parse("[00:10.00][00:40.00]Припев")

        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.text == "Припев" })
        #expect(lines.map(\.time) == [10, 40])
    }

    @Test("skips metadata and empty lines")
    func skipsMetadata() {
        let lines = LRCParser.parse(
            """
            [ar:Artist]
            [ti:Title]
            [00:01.00]
            [00:02.00]Текст
            """
        )

        #expect(lines.map(\.text) == ["Текст"])
    }
}

@Suite("Track lyrics")
struct TrackLyricsTests {
    private let lines = [
        LyricsLine(time: 5, text: "Один"),
        LyricsLine(time: 10, text: "Два"),
        LyricsLine(time: 20, text: "Три"),
    ]

    @Test("resolves the line for a playback position")
    func resolvesCurrentLine() {
        #expect(TrackLyrics.currentIndex(in: lines, position: 0) == nil)
        #expect(TrackLyrics.currentIndex(in: lines, position: 5) == 0)
        #expect(TrackLyrics.currentIndex(in: lines, position: 12) == 1)
        #expect(TrackLyrics.currentIndex(in: lines, position: 500) == 2)
    }
}
