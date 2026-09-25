import Foundation

struct LyricsLine: Equatable, Sendable {
    let time: TimeInterval
    let text: String
}

struct TrackLyrics: Equatable, Sendable {
    let syncedLines: [LyricsLine]
    let plainText: String?

    var isSynced: Bool { syncedLines.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }

    var hasContent: Bool {
        isSynced || !(plainText?.isEmpty ?? true)
    }

    /// Индекс строки, звучащей в указанной позиции трека.
    static func currentIndex(in lines: [LyricsLine], position: TimeInterval) -> Int? {
        guard let first = lines.first, position >= first.time else { return nil }
        return lines.lastIndex { $0.time <= position }
    }
}

/// Разбирает синхронизированный текст формата LRC:
/// `[mm:ss.xx]строка`, у строки может быть несколько таймстемпов.
enum LRCParser {
    private static var timestamp: Regex<(Substring, Substring, Substring, Substring?)> {
        /\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/
    }

    static func parse(_ raw: String) -> [LyricsLine] {
        var lines: [LyricsLine] = []

        for rawLine in raw.split(whereSeparator: \.isNewline) {
            let matches = rawLine.matches(of: timestamp)
            guard let last = matches.last else { continue }

            let text = String(rawLine[last.range.upperBound...])
                .trimmingCharacters(in: .whitespaces)

            for match in matches {
                guard
                    let minutes = Double(match.output.1),
                    let seconds = Double(match.output.2)
                else { continue }

                let fraction = match.output.3.flatMap { digits -> Double? in
                    guard let value = Double(digits) else { return nil }
                    return value / pow(10, Double(digits.count))
                } ?? 0

                lines.append(
                    LyricsLine(time: minutes * 60 + seconds + fraction, text: text)
                )
            }
        }

        // Keep source order for equal timestamps; currentIndex then resolves the
        // last event at that boundary consistently.
        return lines.enumerated().sorted {
            $0.element.time == $1.element.time ? $0.offset < $1.offset : $0.element.time < $1.element.time
        }.map(\.element)
    }
}

struct LyricsRequest: Equatable, Hashable, Sendable {
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval

    init(title: String, artist: String, album: String?, duration: TimeInterval) {
        self.title = title
        self.artist = artist
        self.album = album?.isEmpty == true ? nil : album
        // Match the actual LRCLIB query: metadata polling can vary fractions
        // of a second without changing which lyrics we are requesting.
        self.duration = duration.isFinite && duration >= 0 ? duration.rounded() : duration
    }

    init(track: SpotifyTrack) {
        self.init(title: track.title, artist: track.artist, album: track.album, duration: track.duration)
    }
}

protocol LyricsProviding: Sendable {
    /// `nil` — текст для трека не найден.
    func fetchLyrics(for request: LyricsRequest) async throws -> TrackLyrics?
}

/// Клиент LRCLIB (lrclib.net) — открытый каталог синхронизированных текстов,
/// без ключей и авторизации.
struct LRCLibLyricsClient: LyricsProviding {
    private let load: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(session: URLSession = .shared) {
        load = { try await session.data(for: $0) }
    }

    init(load: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.load = load
    }

    func fetchLyrics(for request: LyricsRequest) async throws -> TrackLyrics? {
        guard request.duration.isFinite, request.duration >= 0,
              let duration = Int(exactly: request.duration.rounded()) else {
            throw URLError(.badURL)
        }
        var query = [
            URLQueryItem(name: "track_name", value: request.title),
            URLQueryItem(name: "artist_name", value: request.artist),
            URLQueryItem(name: "duration", value: String(duration)),
        ]
        if let album = request.album, !album.isEmpty {
            query.append(URLQueryItem(name: "album_name", value: album))
        }
        if let data = try await response(path: "get", query: query, allowsNotFound: true) {
            let record = try JSONDecoder().decode(LRCLibRecord.self, from: data)
            if let lyrics = record.lyrics { return lyrics }
            if record.instrumental == true { return nil }
        }
        // One conservative fallback, without the album restriction. Network,
        // server and decoding failures never turn into a cached "not found".
        guard duration > 0 else { return nil }
        let title = LyricsMatch.searchTitle(request.title)
        guard !title.isEmpty, !request.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let data = try await response(path: "search", query: [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: request.artist),
        ], allowsNotFound: false)
        let records = try JSONDecoder().decode([LRCLibRecord].self, from: data ?? Data())
        return LyricsMatch.select(from: records, for: request)
    }

    private func response(path: String, query: [URLQueryItem], allowsNotFound: Bool) async throws -> Data? {
        try Task.checkCancellation()
        var components = URLComponents(string: "https://lrclib.net/api/\(path)")!
        components.queryItems = query
        var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 12
        request.setValue("TrackPeek (https://github.com/Komortes/TrackPeek)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await load(request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if allowsNotFound, http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode), data.count <= 4_000_000 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
