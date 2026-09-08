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

    @Test("capabilities follow the resolved active source")
    func capabilitiesFollowActiveSource() async {
        let provider = FakeSpotifyProvider(
            result: .failure(SpotifyPlaybackError.spotifyNotRunning),
            activeSource: .appleMusic
        )
        let model = SpotifySpikeModel(provider: provider)

        #expect(model.capabilities == [])
        await model.refresh()
        #expect(model.capabilities == PlaybackCapabilities.capabilities(for: .appleMusic))
    }

    @Test("revoked automation permission surfaces a dedicated availability state")
    func automationDeniedSurfaces() async {
        let provider = FakeSpotifyProvider(
            result: .failure(SpotifyPlaybackError.automationDenied)
        )
        let model = SpotifySpikeModel(provider: provider)

        await model.refresh()

        #expect(model.availability == .automationDenied)
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

    func setShuffle(_ enabled: Bool) throws {}

    func setRepeat(_ mode: RepeatMode) throws {}

    func setVolume(_ volume: Int) throws {}
}

private enum FakeError: LocalizedError {
    case spotifyNotRunning

    var errorDescription: String? {
        "Spotify не запущен."
    }
}

extension SpotifySpikeModelTests {
    @Test("polling and seeking preserve source and secondary controls")
    func preservesSnapshotMetadata() async {
        var track = SpotifyTrack(title: "Song", artist: "Artist", duration: 180,
                                 position: 20, isPlaying: true, source: .appleMusic)
        track.secondary = PlaybackSecondaryState(isShuffling: true, repeatMode: .all, volume: 42)
        let model = SpotifySpikeModel(provider: FakeSpotifyProvider(result: .success(track)))
        await model.refresh()
        await model.refresh()
        #expect(model.activeSource == .appleMusic)
        #expect(model.track?.source == .appleMusic)
        #expect(model.track?.secondary == track.secondary)
        await model.seek(to: 60)
        #expect(model.track?.source == .appleMusic)
        #expect(model.track?.secondary == track.secondary)
    }

    @Test("AppleScript timeout returns before a blocking native script finishes")
    func scriptTimeout() async {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            _ = try await AppleScriptExecutor.execute("delay 1\nreturn 1", timeout: .milliseconds(50))
            Issue.record("Expected a timeout")
        } catch AppleScriptExecutionError.timedOut {
            #expect(start.duration(to: clock.now) < .milliseconds(700))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

extension SpotifySpikeModelTests {
    @Test("a late poll cannot replace a newer snapshot")
    func ignoresStalePoll() async {
        let provider = DelayedSpotifyProvider()
        let model = SpotifySpikeModel(provider: provider)
        let first = Task { await model.refresh() }
        while !(await provider.isWaiting) { await Task.yield() }
        await model.refresh()
        await provider.finishFirst()
        await first.value
        #expect(model.track?.title == "New")
    }
}

private actor DelayedSpotifyProvider: SpotifyPlaybackProviding {
    private var pending: CheckedContinuation<SpotifyTrack, Never>?
    private var calls = 0
    var isWaiting: Bool { pending != nil }
    func fetchCurrentTrack() async throws -> SpotifyTrack {
        calls += 1
        if calls == 1 {
            return await withCheckedContinuation { pending = $0 }
        }
        return SpotifyTrack(title: "New", artist: "Artist", isPlaying: true)
    }
    func finishFirst() {
        pending?.resume(returning: SpotifyTrack(title: "Old", artist: "Artist", isPlaying: true))
        pending = nil
    }
    func activeSource() -> PlaybackSource { .spotify }
    func playPause() throws { }
    func nextTrack() throws { }
    func previousTrack() throws { }
    func seek(to position: TimeInterval) throws { }
    func setShuffle(_ enabled: Bool) throws { }
    func setRepeat(_ mode: RepeatMode) throws { }
    func setVolume(_ volume: Int) throws { }
}
