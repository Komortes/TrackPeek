import Foundation

struct LyricsLine: Equatable, Sendable {
    let time: TimeInterval
    let text: String
}

struct TrackLyrics: Equatable, Sendable {
    let syncedLines: [LyricsLine]
    let plainText: String?

    var isSynced: Bool { !syncedLines.isEmpty }

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
            guard !text.isEmpty else { continue }

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

        return lines.sorted { $0.time < $1.time }
    }
}

struct LyricsRequest: Equatable, Hashable, Sendable {
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
}

protocol LyricsProviding: Sendable {
    /// `nil` — текст для трека не найден.
    func fetchLyrics(for request: LyricsRequest) async throws -> TrackLyrics?
}

/// Клиент LRCLIB (lrclib.net) — открытый каталог синхронизированных текстов,
/// без ключей и авторизации.
struct LRCLibLyricsClient: LyricsProviding {
    var session: URLSession = .shared

    private struct Response: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }

    func fetchLyrics(for request: LyricsRequest) async throws -> TrackLyrics? {
        guard request.duration.isFinite, request.duration >= 0,
              let duration = Int(exactly: request.duration.rounded()) else {
            throw URLError(.badURL)
        }
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var query = [
            URLQueryItem(name: "track_name", value: request.title),
            URLQueryItem(name: "artist_name", value: request.artist),
            URLQueryItem(name: "duration", value: String(duration)),
        ]
        if let album = request.album, !album.isEmpty {
            query.append(URLQueryItem(name: "album_name", value: album))
        }
        components.queryItems = query

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.timeoutInterval = 12
        urlRequest.setValue(
            "TrackPeek (https://github.com/Komortes/TrackPeek)",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 404 {
            return nil
        }
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let payload = try JSONDecoder().decode(Response.self, from: data)
        let lines = payload.syncedLyrics.map(LRCParser.parse) ?? []
        let plain = payload.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines)

        let lyrics = TrackLyrics(
            syncedLines: lines,
            plainText: (plain?.isEmpty ?? true) ? nil : plain
        )
        return lyrics.hasContent ? lyrics : nil
    }
}
