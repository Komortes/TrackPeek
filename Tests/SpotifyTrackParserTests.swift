import Foundation
import Testing
@testable import TrackPeek

@Suite("Spotify track parser")
struct SpotifyTrackParserTests {
    @Test("parses the current track returned by AppleScript")
    func parsesCurrentTrack() throws {
        let track = try SpotifyTrackParser.parse([
            "Jigsaw Falling Into Place",
            "Radiohead",
            "In Rainbows",
            "249250",
            "62.5",
            "https://i.scdn.co/image/example",
            "playing",
        ])

        #expect(track.title == "Jigsaw Falling Into Place")
        #expect(track.artist == "Radiohead")
        #expect(track.album == "In Rainbows")
        #expect(track.duration == 249.25)
        #expect(track.position == 62.5)
        #expect(track.artworkURL == URL(string: "https://i.scdn.co/image/example"))
        #expect(track.isPlaying)
    }

    @Test("supports localized time and a missing artwork URL")
    func supportsMissingArtwork() throws {
        let track = try SpotifyTrackParser.parse([
            "Local Track",
            "Local Artist",
            "",
            "180500",
            "12,25",
            "",
            "paused",
        ])

        #expect(track.album == nil)
        #expect(track.duration == 180.5)
        #expect(track.position == 12.25)
        #expect(track.artworkURL == nil)
        #expect(!track.isPlaying)
    }

    @Test("normalizes Spotify duration from milliseconds to seconds")
    func normalizesDurationUnits() throws {
        let track = try SpotifyTrackParser.parse([
            "Love Attribute",
            "Nate Mercereau",
            "Excellent Traveler",
            "173834",
            "42.5",
            "https://i.scdn.co/image/example",
            "playing",
        ])

        #expect(track.duration == 173.834)
        #expect(track.position == 42.5)
    }

    @Test("rejects an incomplete AppleScript response")
    func rejectsIncompleteResponse() {
        #expect(throws: SpotifyTrackParser.Error.invalidResponse) {
            try SpotifyTrackParser.parse(["Jigsaw Falling Into Place"])
        }
    }

    @Test("parses the extended snapshot with shuffle, repeat and volume")
    func parsesExtendedSnapshot() throws {
        let track = try SpotifyTrackParser.parse([
            "Reckoner", "Radiohead", "In Rainbows", "225000", "12.5",
            "https://example.com/a.jpg", "playing", "true", "off", "80",
        ])
        #expect(track.secondary == PlaybackSecondaryState(isShuffling: true, repeatMode: .off, volume: 80))
    }

    @Test("keeps the legacy 7-field snapshot working without secondary state")
    func legacySnapshotStillParses() throws {
        let track = try SpotifyTrackParser.parse([
            "Reckoner", "Radiohead", "", "225000", "12.5", "", "paused",
        ])
        #expect(track.secondary == nil)
    }
}

extension SpotifyTrackParserTests {
    @Test("rejects non-finite timestamps")
    func rejectsNonFiniteTimes() {
        for invalid in ["nan", "inf", "-inf", "1e999"] {
            #expect(throws: SpotifyTrackParser.Error.self) {
                try SpotifyTrackParser.parse(["Song", "Artist", "Album", invalid, "0", "", "playing"])
            }
        }
    }
}
