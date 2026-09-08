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

@MainActor
@Suite("Lyrics cache lifecycle")
struct LyricsStoreLifecycleTests {
    @Test("transient failures can be retried")
    func retriesFailures() async {
        let provider = RetryLyricsProvider()
        let store = LyricsStore(provider: provider)
        let track = SpotifyTrack(title: "Song", artist: "Artist", isPlaying: true)
        store.prepare(for: track)
        for _ in 0..<1000 {
            if store.state(for: track) == .unavailable { break }
            await Task.yield()
        }
        #expect(store.state(for: track) == .unavailable)
        store.prepare(for: track)
        for _ in 0..<1000 {
            if case .loaded = store.state(for: track) { break }
            await Task.yield()
        }
        #expect(store.state(for: track) == .loaded(TrackLyrics(syncedLines: [], plainText: "Lyrics")))
    }

    @Test("cache evicts old lyrics after 48 tracks")
    func boundsCache() async {
        let provider = RetryLyricsProvider(failFirst: false)
        let store = LyricsStore(provider: provider)
        for index in 0..<49 {
            let track = SpotifyTrack(title: "Song \(index)", artist: "Artist", isPlaying: true)
            store.prepare(for: track)
            for _ in 0..<1000 {
                if case .loaded = store.state(for: track) { break }
                await Task.yield()
            }
            #expect(store.state(for: track) == .loaded(TrackLyrics(syncedLines: [], plainText: "Lyrics")))
        }
        let first = SpotifyTrack(title: "Song 0", artist: "Artist", isPlaying: true)
        #expect(store.state(for: first) == .loading)
    }
}

private actor RetryLyricsProvider: LyricsProviding {
    private var failFirst: Bool
    init(failFirst: Bool = true) { self.failFirst = failFirst }
    func fetchLyrics(for request: LyricsRequest) async throws -> TrackLyrics? {
        if failFirst {
            failFirst = false
            throw URLError(.notConnectedToInternet)
        }
        return TrackLyrics(syncedLines: [], plainText: "Lyrics")
    }
}

@Test("lyrics requests reject durations that cannot be converted to integers")
func invalidLyricsDuration() async {
    for duration in [Double.nan, .infinity, -.infinity, -1, 1e100] {
        do {
            _ = try await LRCLibLyricsClient().fetchLyrics(for: LyricsRequest(
                title: "Song", artist: "Artist", album: nil, duration: duration
            ))
            Issue.record("Expected invalid duration to be rejected")
        } catch let error as URLError {
            #expect(error.code == .badURL)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
