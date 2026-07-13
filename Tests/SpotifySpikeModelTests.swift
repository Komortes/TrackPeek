import Foundation
import Testing
@testable import TrackPeek

@MainActor
@Suite("Spotify spike model")
struct SpotifySpikeModelTests {
    @Test("refresh exposes the current track")
    func refreshExposesCurrentTrack() {
        let provider = FakeSpotifyProvider(
            result: .success(
                SpotifyTrack(title: "Reckoner", artist: "Radiohead", isPlaying: true)
            )
        )
        let model = SpotifySpikeModel(provider: provider)

        model.refresh()

        #expect(model.track?.title == "Reckoner")
        #expect(model.statusText == "Играет")
    }

    @Test("refresh exposes provider errors")
    func refreshExposesProviderErrors() {
        let provider = FakeSpotifyProvider(result: .failure(FakeError.spotifyNotRunning))
        let model = SpotifySpikeModel(provider: provider)

        model.refresh()

        #expect(model.track == nil)
        #expect(model.statusText == "Spotify не запущен.")
    }
}

@MainActor
private final class FakeSpotifyProvider: SpotifyPlaybackProviding {
    let result: Result<SpotifyTrack, Swift.Error>

    init(result: Result<SpotifyTrack, Swift.Error>) {
        self.result = result
    }

    func fetchCurrentTrack() throws -> SpotifyTrack {
        try result.get()
    }

    func playPause() throws {}
}

private enum FakeError: LocalizedError {
    case spotifyNotRunning

    var errorDescription: String? {
        "Spotify не запущен."
    }
}
