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

    @Test("keeps timed empty lines as instrumental gaps while skipping metadata")
    func skipsMetadata() {
        let lines = LRCParser.parse(
            """
            [ar:Artist]
            [ti:Title]
            [00:01.00]
            [00:02.00]Текст
            """
        )

        #expect(lines.map(\.text) == ["", "Текст"])
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
    @Test("lyrics stay visible when duration changes within the same server query")
    func preservesLyricsAcrossEquivalentDurationSnapshots() async {
        let store = LyricsStore(provider: RetryLyricsProvider(failFirst: false))
        let initial = SpotifyTrack(title: "Song", artist: "Artist", duration: 180.1, isPlaying: true)
        store.prepare(for: initial)
        for _ in 0..<1000 {
            if case .loaded = store.state(for: initial) { break }
            await Task.yield()
        }
        let expected = LyricsStore.State.loaded(TrackLyrics(syncedLines: [], plainText: "Lyrics"))
        #expect(store.state(for: initial) == expected)

        // LRCLIB receives duration=180 for both snapshots. Their shared request
        // identity stays unchanged, so the view does not start another lyrics task.
        let refreshed = SpotifyTrack(title: "Song", artist: "Artist", duration: 180.2, position: 2, isPlaying: true)
        #expect(store.state(for: refreshed) == expected)
    }

    @Test("missing and empty album metadata share already loaded lyrics")
    func preservesLyricsAcrossEquivalentAlbumSnapshots() async {
        let store = LyricsStore(provider: RetryLyricsProvider(failFirst: false))
        let initial = SpotifyTrack(title: "Song", artist: "Artist", album: nil, duration: 180, isPlaying: true)
        store.prepare(for: initial)
        for _ in 0..<1000 {
            if case .loaded = store.state(for: initial) { break }
            await Task.yield()
        }
        let expected = LyricsStore.State.loaded(TrackLyrics(syncedLines: [], plainText: "Lyrics"))
        #expect(store.state(for: initial) == expected)

        let refreshed = SpotifyTrack(title: "Song", artist: "Artist", album: "", duration: 180, isPlaying: true)
        #expect(store.state(for: refreshed) == expected)

        // An explicitly different recording must still get its own lookup.
        let differentAlbum = SpotifyTrack(title: "Song", artist: "Artist", album: "Live", duration: 180, isPlaying: true)
        #expect(store.state(for: differentAlbum) == .loading)
    }

    @Test("a late miss from the previous song cannot hide the new song's lyrics")
    func ignoresLateMissAfterTrackSwitch() async {
        let provider = ControlledLyricsProvider()
        let store = LyricsStore(provider: provider)
        let previous = SpotifyTrack(title: "Previous", artist: "Artist", duration: 180, isPlaying: true)
        let current = SpotifyTrack(title: "Current", artist: "Artist", duration: 200, isPlaying: true)

        store.prepare(for: previous)
        guard await provider.waitUntilRequested(count: 1) else { return }
        store.prepare(for: current)
        guard await provider.waitUntilRequested(count: 2) else { return }

        let lyrics = TrackLyrics(syncedLines: [], plainText: "Current song lyrics")
        await provider.complete(id: 1, lyrics: lyrics)
        for _ in 0..<1000 {
            if case .loaded = store.state(for: current) { break }
            await Task.yield()
        }
        #expect(store.state(for: current) == .loaded(lyrics))

        // Deliberately ignore cancellation at the provider boundary, as a late
        // response may already be queued when the user switches tracks.
        await provider.complete(id: 0, lyrics: nil)
        for _ in 0..<100 { await Task.yield() }
        #expect(store.state(for: current) == .loaded(lyrics))
        #expect(store.state(for: previous) == .loading)
        await provider.completeRemaining()
    }

    @Test("returning to a pending song ignores its original late miss")
    func ignoresLateMissAfterReturningToTrack() async {
        let provider = ControlledLyricsProvider()
        let store = LyricsStore(provider: provider)
        let first = SpotifyTrack(title: "First", artist: "Artist", duration: 180, isPlaying: true)
        let second = SpotifyTrack(title: "Second", artist: "Artist", duration: 200, isPlaying: true)

        store.prepare(for: first)
        guard await provider.waitUntilRequested(count: 1) else { return }
        store.prepare(for: second)
        guard await provider.waitUntilRequested(count: 2) else { return }
        store.prepare(for: first)
        guard await provider.waitUntilRequested(count: 3) else { return }

        let lyrics = TrackLyrics(syncedLines: [], plainText: "First song lyrics")
        await provider.complete(id: 2, lyrics: lyrics)
        for _ in 0..<1000 {
            if case .loaded = store.state(for: first) { break }
            await Task.yield()
        }
        #expect(store.state(for: first) == .loaded(lyrics))

        // These requests have the same identity (A) or a now unrelated identity
        // (B), but both belong to canceled tasks from before the final selection.
        await provider.complete(id: 0, lyrics: nil)
        await provider.complete(id: 1, lyrics: nil)
        for _ in 0..<100 { await Task.yield() }
        #expect(store.state(for: first) == .loaded(lyrics))
        #expect(store.state(for: second) == .loading)
        #expect(await provider.requestCount == 3)
        await provider.completeRemaining()
    }

    @Test("multiple surfaces share one pending lyrics request")
    func coalescesDuplicatePreparation() async {
        let provider = ControlledLyricsProvider()
        let store = LyricsStore(provider: provider)
        let track = SpotifyTrack(title: "Song", artist: "Artist", duration: 180, isPlaying: true)

        store.prepare(for: track)
        guard await provider.waitUntilRequested(count: 1) else { return }
        for position in 1...8 {
            store.prepare(for: track.withPosition(Double(position)))
        }
        for _ in 0..<100 { await Task.yield() }
        #expect(await provider.requestCount == 1)

        let lyrics = TrackLyrics(syncedLines: [], plainText: "Shared lyrics")
        await provider.complete(id: 0, lyrics: lyrics)
        for _ in 0..<1000 {
            if case .loaded = store.state(for: track) { break }
            await Task.yield()
        }
        #expect(store.state(for: track) == .loaded(lyrics))
        store.prepare(for: track)
        for _ in 0..<100 { await Task.yield() }
        #expect(await provider.requestCount == 1)
        await provider.completeRemaining()
    }

    @Test("different albums and rounded durations keep separate lyrics")
    func separatesDifferentRecordings() async {
        let store = LyricsStore(provider: RetryLyricsProvider(failFirst: false))
        let studio = SpotifyTrack(title: "Song", artist: "Artist", album: "Studio", duration: 180.1, isPlaying: true)
        store.prepare(for: studio)
        for _ in 0..<1000 {
            if case .loaded = store.state(for: studio) { break }
            await Task.yield()
        }
        let lyrics = TrackLyrics(syncedLines: [], plainText: "Lyrics")
        #expect(store.state(for: studio) == .loaded(lyrics))

        let live = SpotifyTrack(title: "Song", artist: "Artist", album: "Live", duration: 180.1, isPlaying: true)
        let extended = SpotifyTrack(title: "Song", artist: "Artist", album: "Studio", duration: 181.1, isPlaying: true)
        #expect(store.state(for: live) == .loading)
        #expect(store.state(for: extended) == .loading)
        #expect(LyricsRequest(track: studio) != LyricsRequest(track: live))
        #expect(LyricsRequest(track: studio) != LyricsRequest(track: extended))

        for variant in [live, extended] {
            store.prepare(for: variant)
            for _ in 0..<1000 {
                if case .loaded = store.state(for: variant) { break }
                await Task.yield()
            }
            #expect(store.state(for: variant) == .loaded(lyrics))
        }
        #expect(store.state(for: studio) == .loaded(lyrics))
    }

    @Test("transient failures can be retried")
    func retriesFailures() async {
        let provider = RetryLyricsProvider()
        let store = LyricsStore(provider: provider)
        let track = SpotifyTrack(title: "Song", artist: "Artist", isPlaying: true)
        store.prepare(for: track)
        for _ in 0..<1000 {
            if store.state(for: track) == .failed { break }
            await Task.yield()
        }
        #expect(store.state(for: track) == .failed)
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

private actor ControlledLyricsProvider: LyricsProviding {
    private var pending: [Int: CheckedContinuation<TrackLyrics?, Never>] = [:]
    private(set) var requestCount = 0

    func fetchLyrics(for request: LyricsRequest) async throws -> TrackLyrics? {
        let id = requestCount
        requestCount += 1
        return await withCheckedContinuation { pending[id] = $0 }
    }

    func waitUntilRequested(count: Int) async -> Bool {
        for _ in 0..<1000 {
            if requestCount >= count { return true }
            await Task.yield()
        }
        Issue.record("Expected \(count) lyrics requests, received \(requestCount)")
        // A regression must fail rather than hang or leave suspended continuations.
        completeRemaining()
        return false
    }

    func completeRemaining() {
        let abandoned = Array(pending.values)
        pending.removeAll()
        for continuation in abandoned { continuation.resume(returning: nil) }
    }

    func complete(id: Int, lyrics: TrackLyrics?) {
        guard let continuation = pending.removeValue(forKey: id) else {
            Issue.record("No pending lyrics request with id \(id)")
            return
        }
        continuation.resume(returning: lyrics)
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

extension LyricsStoreLifecycleTests {
    @Test("explicit retry refreshes a cached miss, coalesces clicks and preserves loaded lyrics")
    func retriesMissingLyrics() async {
        let provider = ControlledLyricsProvider()
        let store = LyricsStore(provider: provider)
        let track = SpotifyTrack(title: "Song", artist: "Artist", duration: 180, isPlaying: true)
        store.prepare(for: track)
        guard await provider.waitUntilRequested(count: 1) else { return }
        await provider.complete(id: 0, lyrics: nil)
        for _ in 0..<1000 { if store.state(for: track) == .unavailable { break }; await Task.yield() }
        #expect(store.state(for: track) == .unavailable)
        store.prepare(for: track)
        #expect(await provider.requestCount == 1)
        store.retry(for: track)
        store.retry(for: track)
        #expect(store.state(for: track) == .loading)
        guard await provider.waitUntilRequested(count: 2) else { return }
        #expect(store.isLoading(for: track))
        let lyrics = TrackLyrics(syncedLines: [LyricsLine(time: 5, text: "Recovered")], plainText: nil)
        await provider.complete(id: 1, lyrics: lyrics)
        for _ in 0..<1000 { if store.state(for: track) == .loaded(lyrics) { break }; await Task.yield() }
        store.retry(for: track)
        #expect(store.state(for: track) == .loaded(lyrics))
        #expect(!store.isLoading(for: track))
        #expect(await provider.requestCount == 2)
    }

    @Test("timing is shared only for the current recording, resets on source or song change, and stays bounded")
    func timingOffset() {
        let store = LyricsStore()
        let a = SpotifyTrack(title: "A", artist: "Artist", duration: 180.1, isPlaying: true, source: .spotify)
        let b = SpotifyTrack(title: "B", artist: "Artist", duration: 200, isPlaying: true, source: .spotify)
        store.currentTrackDidChange(a)
        store.setOffset(1.5, for: a)
        store.currentTrackDidChange(a.withPosition(10))
        #expect(store.offset(for: a) == 1.5)
        store.currentTrackDidChange(a.withPosition(0)) // Seek/repeat of the same recording.
        #expect(store.offset(for: a) == 1.5)
        #expect(store.offset(for: b) == 0)
        store.currentTrackDidChange(b)
        store.currentTrackDidChange(a)
        #expect(store.offset(for: a) == 0)
        store.setOffset(-1.5, for: a)
        store.currentTrackDidChange(a.tagged(with: .appleMusic))
        #expect(store.offset(for: a.tagged(with: .appleMusic)) == 0)
        store.setOffset(100, for: a)
        #expect(store.offset(for: a) == 10)
        store.setOffset(-100, for: a)
        #expect(store.offset(for: a) == -10)
        store.setOffset(.nan, for: a)
        #expect(store.offset(for: a) == -10)
        store.currentTrackDidChange(nil)
        #expect(store.offset(for: a) == 0)
    }
}

extension LRCParserTests {
    @Test("timed gaps end the previous line and blank-only files are not lyrics")
    func instrumentalGaps() {
        let lines = LRCParser.parse("[00:02]First\n[00:05]\n[00:12]Second\n[00:20]")
        let lyrics = TrackLyrics(syncedLines: lines, plainText: nil)
        #expect(lines.map(\.time) == [2, 5, 12, 20])
        #expect(TrackLyrics.currentIndex(in: lines, position: 7).map { lines[$0].text } == "")
        let gap = LyricStripPresentation.resolve(state: .loaded(lyrics), position: 7, title: "Song", artist: "Artist")
        #expect(gap.status == "Проигрыш")
        #expect(gap.text == "Song — Artist")
        #expect(!TrackLyrics(syncedLines: LRCParser.parse("[00:00]\n[01:00]"), plainText: nil).hasContent)
        let before = LyricStripPresentation.resolve(state: .loaded(lyrics), position: 1, title: "Song", artist: "Artist")
        #expect(before.status == "Ждём первую строку")
        let plainWithEmptyTiming = TrackLyrics(syncedLines: LRCParser.parse("[00:00]"), plainText: "Words")
        #expect(!plainWithEmptyTiming.isSynced)
        #expect(LyricStripPresentation.resolve(state: .loaded(plainWithEmptyTiming), position: 7,
            title: "Song", artist: "Artist").status == "Нет синхронизированного текста")
    }

    @Test("equal timestamps preserve source order for clearing a line")
    func sameTimeOrder() {
        let lines = LRCParser.parse("[00:02]First\n[00:02]\n[00:03]Next")
        #expect(TrackLyrics.currentIndex(in: lines, position: 2).map { lines[$0].text } == "")
    }

    @Test("explicit lyric schedule applies both earlier and later offsets and includes gaps")
    func adjustedTimeline() {
        let now = Date(timeIntervalSince1970: 1000)
        let lines = LRCParser.parse("[00:02]First\n[00:05]\n[00:12]Second")
        for offset in [-2.0, 0, 2] {
            let dates = LyricStripTimeline.dates(lines: lines, position: 0, snapshotDate: now,
                duration: 30, isPlaying: true, isVisible: true, isStale: false, now: now, offset: offset)
            let expected = lines.map { $0.time - offset }.filter { $0 > 0 }
            #expect(dates.count == expected.count + 1)
            for (date, boundary) in zip(dates.dropFirst(), expected) {
                #expect(abs(date.timeIntervalSince(now) - boundary - 0.001) < 0.00001)
                let index = TrackLyrics.currentIndex(in: lines, position: date.timeIntervalSince(now) + offset)
                #expect(index != nil)
            }
        }
        #expect(LyricStripTimeline.dates(lines: lines, position: 0, snapshotDate: now,
            duration: 30, isPlaying: false, isVisible: true, isStale: false, now: now, offset: 1).isEmpty)
    }
}
