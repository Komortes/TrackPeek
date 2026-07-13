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
            "249.25",
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
            "180,5",
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

    @Test("rejects an incomplete AppleScript response")
    func rejectsIncompleteResponse() {
        #expect(throws: SpotifyTrackParser.Error.invalidResponse) {
            try SpotifyTrackParser.parse(["Jigsaw Falling Into Place"])
        }
    }
}
