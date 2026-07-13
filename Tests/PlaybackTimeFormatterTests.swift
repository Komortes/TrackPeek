import Testing
@testable import TrackPeek

@Suite("Playback time formatter")
struct PlaybackTimeFormatterTests {
    @Test("formats playback time as minutes and seconds")
    func formatsMinutesAndSeconds() {
        #expect(PlaybackTimeFormatter.string(from: 0) == "0:00")
        #expect(PlaybackTimeFormatter.string(from: 151) == "2:31")
        #expect(PlaybackTimeFormatter.string(from: 3_661) == "61:01")
    }

    @Test("clamps invalid playback time to zero")
    func clampsInvalidTime() {
        #expect(PlaybackTimeFormatter.string(from: -10) == "0:00")
        #expect(PlaybackTimeFormatter.string(from: .infinity) == "0:00")
    }
}
