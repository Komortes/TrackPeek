import Foundation

/// Конкретный плеер, из которого получен playback-снапшот.
enum PlaybackSource: String, Sendable, Equatable {
    case spotify
    case appleMusic

    var bundleIdentifier: String {
        switch self {
        case .spotify: "com.spotify.client"
        case .appleMusic: "com.apple.Music"
        }
    }

    var displayName: String {
        switch self {
        case .spotify: "Spotify"
        case .appleMusic: "Music"
        }
    }
}

struct SpotifyTrack: Equatable, Sendable {
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let position: TimeInterval
    let artworkURL: URL?
    let isPlaying: Bool
    /// Источник снапшота; проставляется роутером, парсеры его не знают.
    var source: PlaybackSource?

    init(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval = 0,
        position: TimeInterval = 0,
        artworkURL: URL? = nil,
        isPlaying: Bool,
        source: PlaybackSource? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.artworkURL = artworkURL
        self.isPlaying = isPlaying
        self.source = source
    }

    func tagged(with source: PlaybackSource) -> SpotifyTrack {
        var copy = self
        copy.source = source
        return copy
    }
}

enum SpotifyTrackParser {
    enum Error: Swift.Error, Equatable {
        case invalidResponse
    }

    static func parse(_ values: [String]) throws -> SpotifyTrack {
        guard
            values.count >= 7,
            let durationMilliseconds = parseTime(values[3]),
            let position = parseTime(values[4])
        else {
            throw Error.invalidResponse
        }

        return SpotifyTrack(
            title: values[0],
            artist: values[1],
            album: optionalText(values[2]),
            duration: max(durationMilliseconds / 1_000, 0),
            position: max(position, 0),
            artworkURL: URL(string: values[5]),
            isPlaying: values[6].caseInsensitiveCompare("playing") == .orderedSame
        )
    }

    private static func parseTime(_ value: String) -> TimeInterval? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private static func optionalText(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}
