import Foundation

/// Metadata is optional for the exact endpoint's response, mandatory for a
/// search match. Never choose a search result by result order or popularity.
struct LRCLibRecord: Decodable, Sendable {
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let syncedLyrics: String?
    let plainLyrics: String?

    var lyrics: TrackLyrics? {
        guard instrumental != true else { return nil }
        let plain = plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = TrackLyrics(syncedLines: syncedLyrics.map(LRCParser.parse) ?? [],
                                 plainText: plain?.isEmpty == false ? plain : nil)
        return result.hasContent ? result : nil
    }
}

enum LyricsMatch {
    /// Only a mastering suffix is relaxed. Live, acoustic, remixes, featured
    /// artists and actual parenthesized song names remain part of the identity.
    static func searchTitle(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"(?i)\s*(?:[-–—]\s*|\()(?:(?:19|20)\d{2}\s+)?remaster(?:ed)?(?:\s+(?:19|20)\d{2})?\)?\s*$"#,
            with: "", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func select(from records: [LRCLibRecord], for request: LyricsRequest) -> TrackLyrics? {
        guard request.duration > 0, request.duration.isFinite, records.count <= 100 else { return nil }
        let title = normalized(searchTitle(request.title))
        let artist = normalized(request.artist)
        guard !title.isEmpty, !artist.isEmpty else { return nil }
        let matches: [(album: String, lyrics: TrackLyrics)] = records.compactMap { record in
            guard let name = record.trackName, let performer = record.artistName,
                  let duration = record.duration, duration.isFinite, duration > 0,
                  normalized(searchTitle(name)) == title, normalized(performer) == artist,
                  abs(duration - request.duration) <= 2, let lyrics = record.lyrics else { return nil }
            return (normalized(record.albumName ?? ""), lyrics)
        }
        let album = normalized(request.album ?? "")
        let sameAlbum = album.isEmpty ? [] : matches.filter { $0.album == album }
        let candidates = (sameAlbum.isEmpty ? matches : sameAlbum).map(\.lyrics)
        guard let first = candidates.first, candidates.allSatisfy({ $0 == first }) else { return nil }
        return first
    }
}
