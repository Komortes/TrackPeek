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
    private(set) var commandCount = 0
    private var commandError: (any Swift.Error)?
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

    func setResult(_ result: Result<SpotifyTrack, Swift.Error>) {
        self.result = result
    }

    func setCommandError(_ error: any Swift.Error) {
        commandError = error
    }

    func fetchCurrentTrack() throws -> SpotifyTrack {
        try result.get()
    }

    func activeSource() -> PlaybackSource {
        resolvedActiveSource
    }

    func playPause() throws {
        commandCount += 1
        if let commandError { throw commandError }
    }

    func nextTrack() throws {
        commandCount += 1
        if let nextTrackValue {
            result = .success(nextTrackValue)
        }
    }

    func previousTrack() throws {
        commandCount += 1
        if let previousTrackValue {
            result = .success(previousTrackValue)
        }
    }

    func seek(to position: TimeInterval) throws {
        commandCount += 1
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

    func setShuffle(_ enabled: Bool) throws { commandCount += 1 }

    func setRepeat(_ mode: RepeatMode) throws { commandCount += 1 }

    func setVolume(_ volume: Int) throws { commandCount += 1 }
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
        let executor = AppleScriptExecutor()
        let clock = ContinuousClock()
        let start = clock.now
        do {
            _ = try await executor.run("delay 1\nreturn 1", timeout: .milliseconds(50))
            Issue.record("Expected a timeout")
        } catch AppleScriptExecutionError.timedOut {
            #expect(start.duration(to: clock.now) < .milliseconds(700))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        await executor.shutdown()
    }
}

extension SpotifySpikeModelTests {
    @Test("a late poll cannot replace a newer snapshot")
    func ignoresStalePoll() async throws {
        let provider = DelayedSpotifyProvider()
        let model = SpotifySpikeModel(provider: provider)
        let first = Task { await model.refresh() }
        try await waitForFirstFetch(provider)
        await model.refresh(replacingCurrent: true)
        await provider.finishFirst()
        await first.value
        #expect(model.track?.title == "New")
    }
}

private actor DelayedSpotifyProvider: SpotifyPlaybackProviding {
    private var pending: CheckedContinuation<SpotifyTrack, Never>?
    private(set) var calls = 0
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

extension SpotifySpikeModelTests {
    @Test("transient failure freezes the last snapshot and recovery resets backoff")
    func retainsStaleSnapshotAndRecovers() async throws {
        var track = SpotifyTrack(title: "Song", artist: "Artist", duration: 180,
                                 position: 20, isPlaying: true, source: .appleMusic)
        track.secondary = PlaybackSecondaryState(isShuffling: true, repeatMode: .all, volume: 42)
        let provider = FakeSpotifyProvider(result: .success(track), activeSource: .appleMusic)
        let model = SpotifySpikeModel(provider: provider)
        await model.refresh()
        let successfulDate = try #require(model.lastSuccessfulRefresh)
        let originalSnapshotDate = model.snapshotDate
        #expect(model.nextRefreshDelay == 2)

        await provider.setResult(.failure(SpotifyTrackParser.Error.invalidResponse))
        await model.refresh()

        let stale = try #require(model.track)
        #expect(stale.title == track.title)
        #expect(stale.source == track.source)
        #expect(stale.secondary == track.secondary)
        #expect(!stale.isPlaying)
        let frozenPosition = min(track.duration, track.position + model.snapshotDate.timeIntervalSince(originalSnapshotDate))
        #expect(abs(stale.position - frozenPosition) < 0.01)
        #expect(model.isStale)
        #expect(model.availability == .unavailable)
        #expect(model.lastSuccessfulRefresh == successfulDate)
        #expect(model.consecutiveFailures == 1)
        #expect(model.nextRefreshDelay == 2)

        await model.refresh()
        #expect(model.track?.position == stale.position)
        #expect(model.nextRefreshDelay == 4)

        await provider.setResult(.success(track.withPosition(70)))
        await model.refresh()
        #expect(model.track?.position == 70)
        #expect(model.track?.isPlaying == true)
        #expect(model.availability == .ready)
        #expect(!model.isStale)
        #expect(model.consecutiveFailures == 0)
        #expect(model.nextRefreshDelay == 2)
        let recoveredDate = try #require(model.lastSuccessfulRefresh)
        #expect(recoveredDate >= successfulDate)
    }

    @Test("transient failures back off to a bounded polling interval")
    func capsRetryDelay() async {
        let provider = FakeSpotifyProvider(result: .failure(SpotifyTrackParser.Error.invalidResponse))
        let model = SpotifySpikeModel(provider: provider)
        for (index, delay) in [2.0, 4, 8, 16, 30, 30, 30].enumerated() {
            await model.refresh()
            #expect(model.nextRefreshDelay == delay)
            #expect(model.consecutiveFailures == index + 1)
            #expect(!model.isRefreshing)
        }
    }

    @Test("denied permission stops polling and a closed player clears the old track")
    func terminalErrorsClearSnapshot() async {
        let track = SpotifyTrack(title: "Song", artist: "Artist", isPlaying: true)
        let provider = FakeSpotifyProvider(result: .success(track))
        let model = SpotifySpikeModel(provider: provider)
        await model.refresh()
        await provider.setResult(.failure(SpotifyPlaybackError.automationDenied))
        await model.refresh()
        #expect(model.track == nil)
        #expect(model.availability == .automationDenied)
        #expect(model.nextRefreshDelay == nil)

        await provider.setResult(.success(track))
        await model.refresh()
        await provider.setResult(.failure(SpotifyPlaybackError.spotifyNotRunning))
        await model.refresh()
        #expect(model.track == nil)
        #expect(model.availability == .spotifyNotRunning)
        #expect(model.nextRefreshDelay == 30)
    }

    @Test("paused playback polls less often than playing playback")
    func pausedPollingInterval() async {
        let provider = FakeSpotifyProvider(result: .success(
            SpotifyTrack(title: "Song", artist: "Artist", isPlaying: false)
        ))
        let model = SpotifySpikeModel(provider: provider)
        await model.refresh()
        #expect(model.nextRefreshDelay == 4)
        #expect(model.lastSuccessfulRefresh != nil)
        #expect(!model.isStale)
    }

    @Test("overlapping refreshes share one fetch")
    func coalescesRefreshes() async throws {
        let provider = DelayedSpotifyProvider()
        let model = SpotifySpikeModel(provider: provider)
        let first = Task { await model.refresh() }
        try await waitForFirstFetch(provider)
        #expect(model.isRefreshing)
        // This task finishes the suspended provider only after the second caller
        // has entered refresh and yielded on the same main actor.
        let finish = Task {
            await provider.finishFirst()
        }
        await model.refresh()
        await finish.value
        await first.value
        #expect(await provider.calls == 1)
        #expect(model.track?.title == "Old")
        #expect(!model.isRefreshing)
    }

    @Test("invalidating a pending refresh prevents a late result from restoring it")
    func invalidationRejectsLateResult() async throws {
        let provider = DelayedSpotifyProvider()
        let model = SpotifySpikeModel(provider: provider)
        let pending = Task { await model.refresh() }
        try await waitForFirstFetch(provider)
        model.invalidate(clearTrack: true)
        #expect(!model.isRefreshing)
        await provider.finishFirst()
        await pending.value
        #expect(model.track == nil)
        #expect(model.lastSuccessfulRefresh == nil)
        await model.refresh()
        #expect(model.track?.title == "New")
        #expect(model.availability == .ready)
    }

    @Test("invalidation retains a frozen snapshot until the selected source changes")
    func invalidationFreezesOrClearsSnapshot() async {
        let provider = FakeSpotifyProvider(result: .success(
            SpotifyTrack(title: "Song", artist: "Artist", duration: 100, position: 20, isPlaying: true)
        ))
        let model = SpotifySpikeModel(provider: provider)
        await model.refresh()
        model.invalidate()
        #expect(model.track?.title == "Song")
        #expect(model.track?.isPlaying == false)
        #expect(model.isStale)
        model.invalidate(clearTrack: true)
        #expect(model.track == nil)
    }

    @Test("stale controls do not send commands to an unavailable player")
    func staleControlsAreBlocked() async {
        let provider = FakeSpotifyProvider(result: .success(
            SpotifyTrack(title: "Song", artist: "Artist", duration: 100, position: 20, isPlaying: true)
        ))
        let model = SpotifySpikeModel(provider: provider)
        await model.refresh()
        await provider.setResult(.failure(SpotifyTrackParser.Error.invalidResponse))
        await model.refresh()
        let frozenTrack = model.track
        await model.togglePlayback()
        await model.nextTrack()
        await model.previousTrack()
        await model.seek(to: 50)
        await model.setShuffle(true)
        await model.setRepeat(.all)
        await model.setVolume(80)
        #expect(await provider.commandCount == 0)
        #expect(model.track == frozenTrack)
        #expect(model.isStale)
    }

    @Test("recovery refreshes never replay an ambiguous failed playback command")
    func failedCommandIsNotRetried() async {
        let provider = FakeSpotifyProvider(result: .success(
            SpotifyTrack(title: "Song", artist: "Artist", isPlaying: true)
        ))
        let model = SpotifySpikeModel(provider: provider)
        await model.refresh()
        await provider.setCommandError(AppleScriptExecutionError.timedOut)
        await model.togglePlayback()
        await model.refresh()
        await model.refresh()
        #expect(await provider.commandCount == 1)
        #expect(model.availability == .ready)
    }
}

private func waitForFirstFetch(_ provider: DelayedSpotifyProvider) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !(await provider.isWaiting), ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(await provider.isWaiting, "Provider did not start within two seconds")
}

@Test("Automation denial is classified by error number independently of message language")
func classifiesAutomationDeniedNumber() async {
    let executor = AppleScriptExecutor()
    do {
        _ = try await executor.run("error \"arbitrary localized message\" number -1743")
        Issue.record("Expected denied permission")
    } catch AppleScriptExecutionError.automationDenied {
        // No TCC request is made: the script only returns a synthetic error.
    } catch {
        Issue.record("Unexpected classification: \(error)")
    }
    await executor.shutdown()
}
