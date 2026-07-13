import Testing
@testable import TrackPeek

@Suite("Spotify track parser")
struct SpotifyTrackParserTests {
    @Test("parses the current track returned by AppleScript")
    func parsesCurrentTrack() throws {
        let track = try SpotifyTrackParser.parse([
            "Jigsaw Falling Into Place",
            "Radiohead",
            "playing",
        ])

        #expect(track.title == "Jigsaw Falling Into Place")
        #expect(track.artist == "Radiohead")
        #expect(track.isPlaying)
    }

    @Test("rejects an incomplete AppleScript response")
    func rejectsIncompleteResponse() {
        #expect(throws: SpotifyTrackParser.Error.invalidResponse) {
            try SpotifyTrackParser.parse(["Jigsaw Falling Into Place"])
        }
    }
}
