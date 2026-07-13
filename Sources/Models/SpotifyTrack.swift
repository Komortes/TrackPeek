import Foundation

struct SpotifyTrack: Equatable, Sendable {
    let title: String
    let artist: String
    let isPlaying: Bool
}

enum SpotifyTrackParser {
    enum Error: Swift.Error, Equatable {
        case invalidResponse
    }

    static func parse(_ values: [String]) throws -> SpotifyTrack {
        guard values.count >= 3 else {
            throw Error.invalidResponse
        }

        return SpotifyTrack(
            title: values[0],
            artist: values[1],
            isPlaying: values[2].caseInsensitiveCompare("playing") == .orderedSame
        )
    }
}
