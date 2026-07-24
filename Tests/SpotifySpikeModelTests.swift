import Foundation
import Testing
@testable import TrackPeek

@MainActor
@Suite("Spotify spike model")
struct SpotifySpikeModelTests {
    @Test("starts in the loading state")
    func startsLoading() {
        let provider = FakeSpotifyProvider(
            result: .success(
                SpotifyTrack(title: "Reckoner", artist: "Radiohead", isPlaying: true)
            )
        )

        let model = SpotifySpikeModel(provider: provider)

        #expect(model.availability == .loading)
    }

    @Test("refresh exposes the current track")
    func refreshExposesCurrentTrack() async {
        let provider = FakeSpotifyProvider(
            result: .success(
                SpotifyTrack(title: "Reckoner", artist: "Radiohead", isPlaying: true)
            )
        )
        let model = SpotifySpikeModel(provider: provider)

        await model.refresh()

        #expect(model.track?.title == "Reckoner")
        #expect(model.statusText == "Играет")
        #expect(model.availability == .ready)
    }

    @Test("refresh exposes provider errors")
    func refreshExposesProviderErrors() async {
        let provider = FakeSpotifyProvider(result: .failure(FakeError.spotifyNotRunning))
        let model = SpotifySpikeModel(provider: provider)

        await model.refresh()

        #expect(model.track == nil)
        #expect(model.statusText == "Spotify не запущен.")
        #expect(model.availability == .unavailable)
    }

    @Test("distinguishes Spotify not running")
    func distinguishesSpotifyNotRunning() async {
        let provider = FakeSpotifyProvider(
            result: .failure(SpotifyPlaybackError.spotifyNotRunning)
        )
        let model = SpotifySpikeModel(provider: provider)

        await model.refresh()

        #expect(model.track == nil)
        #expect(model.availability == .spotifyNotRunning)
    }

    @Test("treats an empty stopped snapshot as nothing playing")
    func treatsStoppedSnapshotAsNothingPlaying() async {
        let provider = FakeSpotifyProvider(
            result: .success(
                SpotifyTrack(title: "", artist: "", isPlaying: false)
            )
        )
        let model = SpotifySpikeModel(provider: provider)

        await model.refresh()

        #expect(model.track == nil)
        #expect(model.availability == .nothingPlaying)
    }

    @Test("next track refreshes the playback snapshot")
    func nextTrackRefreshesSnapshot() async {
        let provider = FakeSpotifyProvider(
            result: .success(
                SpotifyTrack(title: "Reckoner", artist: "Radiohead", isPlaying: true)
            ),
            nextTrack: SpotifyTrack(title: "House of Cards", artist: "Radiohead", isPlaying: true)
        )
        let model = SpotifySpikeModel(provider: provider)
        await model.refresh()

        await model.nextTrack()

        #expect(model.track?.title == "House of Cards")
    }

    @Test("refresh exposes the resolved active source even when the track is nil")
    func refreshExposesActiveSourceOnFailure() async {
        let provider = FakeSpotifyProvider(
            result: .failure(SpotifyPlaybackError.spotifyNotRunning),
            activeSource: .appleMusic
        )
        let model = SpotifySpikeModel(provider: provider)

        await model.refresh()

        #expect(model.track == nil)
        #expect(model.activeSource == .appleMusic)
        #expect(model.activeSourceDisplayName == "Music")
    }

    @Test("previous track refreshes the playback snapshot")
    func previousTrackRefreshesSnapshot() async {
        let provider = FakeSpotifyProvider(
            result: .success(
                SpotifyTrack(title: "Reckoner", artist: "Radiohead", isPlaying: true)
            ),
            previousTrack: SpotifyTrack(title: "Nude", artist: "Radiohead", isPlaying: true)
        )
        let model = SpotifySpikeModel(provider: provider)
        await model.refresh()

        await model.previousTrack()

        #expect(model.track?.title == "Nude")
    }

    @Test("seek clamps the requested position to the track duration")
    func seekClampsToDuration() async {
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
        await model.refresh()

        await model.seek(to: 240)

        #expect(model.track?.position == 180)
    }
}

private actor FakeSpotifyProvider: SpotifyPlaybackProviding {
    private var result: Result<SpotifyTrack, Swift.Error>
    private let nextTrackValue: SpotifyTrack?
    private let previousTrackValue: SpotifyTrack?
    private let resolvedActiveSource: PlaybackSource

    init(
        result: Result<SpotifyTrack, Swift.Error>,
        nextTrack: SpotifyTrack? = nil,
        previousTrack: SpotifyTrack? = nil,
        activeSource: PlaybackSource = .spotify
    ) {
        self.result = result
        self.nextTrackValue = nextTrack
        self.previousTrackValue = previousTrack
        self.resolvedActiveSource = activeSource
    }

    func fetchCurrentTrack() throws -> SpotifyTrack {
        try result.get()
    }

    func activeSource() -> PlaybackSource {
        resolvedActiveSource
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
