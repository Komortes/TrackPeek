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

    @Test("lyrics transport does not retain cacheable exact or fallback HTTP responses", arguments: [false, true])
    func transportDoesNotCacheResponses(fallback: Bool) async throws {
        // The control proves that bypassing cache reads still permits writes.
        // Both sessions are isolated from the app's real cache and network.
        for control in [true, false] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let cache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 4_000_000, directory: directory)
            defer {
                cache.removeAllCachedResponses()
                try? FileManager.default.removeItem(at: directory)
            }
            let configuration = control ? URLSessionConfiguration.default : LRCLibLyricsClient.defaultSession.configuration
            if configuration.urlCache != nil {
                // Preserve whether caching is enabled while redirecting any writes
                // to this test's disposable cache, including in a failing regression.
                configuration.urlCache = cache
            }
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            configuration.protocolClasses = [CacheableLyricsProtocol.self]
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }

            let request = LyricsRequest(title: fallback ? "Fallback Fixture" : "Exact Fixture",
                                        artist: "Synthetic Artist", album: "Synthetic Album", duration: 180)
            let result = try await LRCLibLyricsClient(session: session).fetchLyrics(for: request)
            #expect(result?.plainText == "Synthetic lyrics")
            #expect((cache.currentMemoryUsage > 0) == control)
            if !control {
                #expect(session.configuration.urlCache == nil)
            }
        }
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

private final class CacheableLyricsProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let title = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "track_name" })?.value else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let isSearch = url.path == "/api/search"
        let isMiss = !isSearch && title == "Fallback Fixture"
        let record: [String: Any] = ["trackName": title, "artistName": "Synthetic Artist",
            "albumName": "Synthetic Album", "duration": 180, "plainLyrics": "Synthetic lyrics"]
        let body = isMiss ? Data() : try! JSONSerialization.data(withJSONObject: isSearch ? [record] : record)
        let response = HTTPURLResponse(url: url, statusCode: isMiss ? 404 : 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Cache-Control": "public, max-age=3600",
                                                      "Content-Type": "application/json",
                                                      "Content-Length": String(body.count)])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
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
