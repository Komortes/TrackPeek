import Foundation
import Testing
@testable import TrackPeek

@Suite("Conservative lyrics lookup")
struct LyricsLookupTests {
    private let request = LyricsRequest(title: "Song", artist: "Artist", album: "Album", duration: 180)

    @Test("exact results avoid a search, and an instrumental response does not trigger fallback")
    func exactAndInstrumental() async throws {
        for instrumental in [false, true] {
            let body = record(instrumental: instrumental)
            let http = LyricsHTTPFixture([(200, body)])
            let result = try await LRCLibLyricsClient(load: { try await http.load($0) }).fetchLyrics(for: request)
            #expect((result == nil) == instrumental)
            #expect(await http.requests.count == 1)
        }
    }

    @Test("one fallback omits the album, verifies metadata, and bypasses cached misses")
    func albumFallback() async throws {
        let http = LyricsHTTPFixture([(404, Data()), (200, array([record(album: "Reissue")]))])
        let result = try await LRCLibLyricsClient(load: { try await http.load($0) }).fetchLyrics(for: request)
        #expect(result?.plainText == "Words")
        let calls = await http.requests
        #expect(calls.count == 2)
        #expect(calls.map { $0.url?.path } == ["/api/get", "/api/search"])
        let query = URLComponents(url: calls[1].url!, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query?.contains { $0.name == "album_name" } == false)
        #expect(calls.allSatisfy { $0.cachePolicy == .reloadIgnoringLocalCacheData })
    }

    @Test("fallback rejects different artists, versions, unknown durations and ambiguous text")
    func rejectsUnsafeMatches() async throws {
        let cases: [[Data]] = [
            [record(artist: "Other Artist")], [record(title: "Song (Live)")],
            [record(title: "Song - Acoustic")], [record(title: "Song (Remix)")],
            [record(duration: 183)], [record(duration: 0)],
            [record(text: "Version A"), record(text: "Version B")],
            [record(instrumental: true)],
            [Data(#"{"trackName":"Song","artistName":"Artist","plainLyrics":"Words"}"#.utf8)],
        ]
        for records in cases {
            let http = LyricsHTTPFixture([(404, Data()), (200, array(records))])
            #expect(try await LRCLibLyricsClient(load: { try await http.load($0) }).fetchLyrics(for: request) == nil)
        }
    }

    @Test("remaster suffix and formatting differences are allowed while live remains distinct")
    func remaster() async throws {
        let request = LyricsRequest(title: "Song - 2011 Remaster", artist: "ARTIST", album: "Album", duration: 180)
        let http = LyricsHTTPFixture([(404, Data()), (200, array([record(title: "song", duration: 182)]))])
        #expect(try await LRCLibLyricsClient(load: { try await http.load($0) }).fetchLyrics(for: request)?.plainText == "Words")
        #expect(LyricsMatch.searchTitle("Song (Live) - Remastered 2011") == "Song (Live)")
        #expect(LyricsMatch.searchTitle("Song (Acoustic)") == "Song (Acoustic)")
        let search = try #require(await http.requests.last?.url)
        #expect(URLComponents(url: search, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "track_name" }?.value == "Song")
    }

    @Test("matching album wins, identical duplicates are safe, competing lyrics are rejected")
    func candidateRanking() async throws {
        let cases: [([Data], String?)] = [
            ([record(album: "Reissue", text: "Other"), record(text: "Exact")], "Exact"),
            ([record(album: "A"), record(album: "B")], "Words"),
            ([record(album: "A", text: "A"), record(album: "B", text: "B")], nil),
        ]
        for (records, expected) in cases {
            let http = LyricsHTTPFixture([(404, Data()), (200, array(records))])
            let result = try await LRCLibLyricsClient(load: { try await http.load($0) }).fetchLyrics(for: request)
            #expect(result?.plainText == expected)
        }
    }

    @Test("server and invalid JSON errors never become a confirmed miss or cause extra requests")
    func errors() async {
        for responses in [[(503, Data())], [(200, Data("invalid".utf8))], [(404, Data()), (429, Data())]] {
            let http = LyricsHTTPFixture(responses)
            do {
                _ = try await LRCLibLyricsClient(load: { try await http.load($0) }).fetchLyrics(for: request)
                Issue.record("Expected lookup failure")
            } catch { }
            #expect(await http.requests.count == responses.count)
        }
    }

    @Test("cancellation after exact miss prevents launching fallback")
    func cancellation() async throws {
        let gate = LyricsLookupGate()
        let task = Task { try await LRCLibLyricsClient(load: { try await gate.load($0) }).fetchLyrics(for: request) }
        for _ in 0..<1000 { if await gate.calls > 0 { break }; await Task.yield() }
        #expect(await gate.calls == 1)
        task.cancel()
        await gate.finish()
        do { _ = try await task.value; Issue.record("Expected cancellation") }
        catch is CancellationError { }
        catch { Issue.record("Unexpected error: \(error)") }
        #expect(await gate.calls == 1)
    }

    private func record(title: String = "Song", artist: String = "Artist", album: String = "Album",
                        duration: Double = 180, text: String = "Words", instrumental: Bool = false) -> Data {
        try! JSONSerialization.data(withJSONObject: ["trackName": title, "artistName": artist,
            "albumName": album, "duration": duration, "plainLyrics": text, "instrumental": instrumental])
    }

    private func array(_ records: [Data]) -> Data {
        Data(("[" + records.map { String(decoding: $0, as: UTF8.self) }.joined(separator: ",") + "]").utf8)
    }
}

private actor LyricsHTTPFixture {
    var responses: [(Int, Data)]
    private(set) var requests: [URLRequest] = []
    init(_ responses: [(Int, Data)]) { self.responses = responses }
    func load(_ request: URLRequest) throws -> (Data, URLResponse) {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        let (status, data) = responses.removeFirst()
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private actor LyricsLookupGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var calls = 0
    func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        calls += 1
        await withCheckedContinuation { continuation = $0 }
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
    }
    func finish() { continuation?.resume(); continuation = nil }
}
