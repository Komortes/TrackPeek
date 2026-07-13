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

    @Test("next track refreshes the playback snapshot")
    func nextTrackRefreshesSnapshot() {
        let provider = FakeSpotifyProvider(
            result: .success(
                SpotifyTrack(title: "Reckoner", artist: "Radiohead", isPlaying: true)
            ),
            nextTrack: SpotifyTrack(title: "House of Cards", artist: "Radiohead", isPlaying: true)
        )
        let model = SpotifySpikeModel(provider: provider)
        model.refresh()

        model.nextTrack()

        #expect(model.track?.title == "House of Cards")
    }

    @Test("previous track refreshes the playback snapshot")
    func previousTrackRefreshesSnapshot() {
        let provider = FakeSpotifyProvider(
            result: .success(
                SpotifyTrack(title: "Reckoner", artist: "Radiohead", isPlaying: true)
            ),
            previousTrack: SpotifyTrack(title: "Nude", artist: "Radiohead", isPlaying: true)
        )
        let model = SpotifySpikeModel(provider: provider)
        model.refresh()

        model.previousTrack()

        #expect(model.track?.title == "Nude")
    }

    @Test("seek clamps the requested position to the track duration")
    func seekClampsToDuration() {
        let provider = FakeSpotifyProvider(
            result: .success(
                SpotifyTrack(
                    title: "Reckoner",
                    artist: "Radiohead",
                    duration: 180,
                    position: 30,
                    isPlaying: true
                )
            )
        )
        let model = SpotifySpikeModel(provider: provider)
        model.refresh()

        model.seek(to: 240)

        #expect(model.track?.position == 180)
    }
}

@MainActor
private final class FakeSpotifyProvider: SpotifyPlaybackProviding {
    private var result: Result<SpotifyTrack, Swift.Error>
    private let nextTrackValue: SpotifyTrack?
    private let previousTrackValue: SpotifyTrack?

    init(
        result: Result<SpotifyTrack, Swift.Error>,
        nextTrack: SpotifyTrack? = nil,
        previousTrack: SpotifyTrack? = nil
    ) {
        self.result = result
        self.nextTrackValue = nextTrack
        self.previousTrackValue = previousTrack
    }

    func fetchCurrentTrack() throws -> SpotifyTrack {
        try result.get()
    }

    func playPause() throws {}

    func nextTrack() throws {
        if let nextTrackValue {
            result = .success(nextTrackValue)
        }
    }

    func previousTrack() throws {
        if let previousTrackValue {
            result = .success(previousTrackValue)
        }
    }

    func seek(to position: TimeInterval) throws {
        guard case let .success(track) = result else {
            return
        }

        result = .success(
            SpotifyTrack(
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration,
                position: position,
                artworkURL: track.artworkURL,
                isPlaying: track.isPlaying
            )
        )
    }
}

private enum FakeError: LocalizedError {
    case spotifyNotRunning

    var errorDescription: String? {
        "Spotify не запущен."
    }
}
