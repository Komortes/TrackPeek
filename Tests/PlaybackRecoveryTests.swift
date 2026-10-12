import Foundation
import Testing
@testable import TrackPeek

@Suite("Automatic playback source selection")
struct PlaybackSourceRouterTests {
    @Test("a paused fallback is read once when the primary fails")
    func readsFallbackOnce() async throws {
        let spotify = RouterTestProvider(result: .failure(SpotifyPlaybackError.spotifyNotRunning))
        let music = RouterTestProvider(result: .success(SpotifyTrack(title: "Paused", artist: "Artist", isPlaying: false)))
        let router = PlaybackSourceRouter(spotify: spotify, appleMusic: music, preference: { .auto }, isRunning: { _ in true })
        let track = try await router.fetchCurrentTrack()
        #expect(track.title == "Paused")
        #expect(track.source == .appleMusic)
        #expect(await music.fetchCount == 1)
        #expect(await router.activeSource() == .appleMusic)
    }

    @Test("cancellation from the fallback is propagated instead of selecting a paused primary")
    func propagatesFallbackCancellation() async {
        let spotify = RouterTestProvider(result: .success(SpotifyTrack(title: "Paused", artist: "Artist", isPlaying: false)))
        let music = RouterTestProvider(result: .failure(CancellationError()))
        let router = PlaybackSourceRouter(spotify: spotify, appleMusic: music, preference: { .auto }, isRunning: { _ in true })
        await #expect(throws: CancellationError.self) { try await router.fetchCurrentTrack() }
    }

    @Test("a playing secondary wins and subsequent commands go to that player")
    func routesCommandsToSelectedPlayer() async throws {
        let spotify = RouterTestProvider(result: .success(SpotifyTrack(title: "Paused", artist: "Artist", isPlaying: false)))
        let music = RouterTestProvider(result: .success(SpotifyTrack(title: "Playing", artist: "Artist", isPlaying: true)))
        let router = PlaybackSourceRouter(spotify: spotify, appleMusic: music, preference: { .auto }, isRunning: { _ in true })
        #expect(try await router.fetchCurrentTrack().source == .appleMusic)
        try await router.playPause()
        #expect(await music.playPauseCount == 1)
        #expect(await spotify.playPauseCount == 0)
    }

    @Test("a stopped primary cannot hide a paused song in the secondary")
    func prefersActualSongOverEmptySnapshot() async throws {
        let spotify = RouterTestProvider(result: .success(SpotifyTrack(title: "", artist: "", isPlaying: false)))
        let music = RouterTestProvider(result: .success(SpotifyTrack(title: "Paused song", artist: "Artist", isPlaying: false)))
        let router = PlaybackSourceRouter(spotify: spotify, appleMusic: music, preference: { .auto }, isRunning: { _ in true })
        #expect(try await router.fetchCurrentTrack().title == "Paused song")
    }
}

private actor RouterTestProvider: SpotifyPlaybackProviding {
    let result: Result<SpotifyTrack, Error>
    private(set) var fetchCount = 0
    private(set) var playPauseCount = 0
    init(result: Result<SpotifyTrack, Error>) { self.result = result }
    func fetchCurrentTrack() throws -> SpotifyTrack { fetchCount += 1; return try result.get() }
    func activeSource() -> PlaybackSource { .spotify }
    func playPause() { playPauseCount += 1 }
    func nextTrack() { }
    func previousTrack() { }
    func seek(to position: TimeInterval) { }
    func setShuffle(_ enabled: Bool) { }
    func setRepeat(_ mode: RepeatMode) { }
    func setVolume(_ volume: Int) { }
}

@MainActor
@Suite("Playback lifecycle recovery")
struct PlaybackRecoveryTests {
    @Test("coordinator clears timing adjustments on track changes even without visible lyrics")
    func lyricsTimingLifecycle() async throws {
        let fixture = RecoveryFixture()
        defer { fixture.stop() }
        fixture.coordinator.start()
        try await waitUntil { await fixture.provider.hasPendingFetch(1) }
        let a = recoveryTrack("A")
        await fixture.provider.finishFetch(1, with: .success(a))
        try await waitUntil { fixture.coordinator.nextRefreshDate != nil }
        fixture.coordinator.lyricsStore.setOffset(2, for: a)
        fixture.coordinator.requestRefresh()
        try await waitUntil { await fixture.provider.hasPendingFetch(2) }
        await fixture.provider.finishFetch(2, with: .success(recoveryTrack("B")))
        try await waitUntil { fixture.model.track?.title == "B" && !fixture.model.isRefreshing }
        #expect(fixture.coordinator.lyricsStore.offset(for: a) == 0)
    }

    @Test("saving mode reschedules polls, preserves appearance and lets manual refresh through")
    func resourceSaving() async throws {
        let fixture = RecoveryFixture()
        defer { fixture.stop() }
        fixture.defaults.set(true, forKey: WidgetPreferences.outlineShimmerKey)
        fixture.coordinator.start()
        try await waitUntil { await fixture.provider.hasPendingFetch(1) }
        await fixture.provider.finishFetch(1, with: .success(recoveryTrack("Paused")))
        try await waitUntil { fixture.coordinator.nextRefreshDate != nil }
        fixture.defaults.set(ResourceUsageMode.economical.rawValue, forKey: ResourceUsageMode.storageKey)
        fixture.coordinator.resourcePolicyDidChange()
        #expect(fixture.coordinator.isSavingResources)
        #expect(try #require(fixture.coordinator.nextRefreshDate).timeIntervalSinceNow > 7)
        #expect(fixture.defaults.bool(forKey: WidgetPreferences.outlineShimmerKey))
        fixture.coordinator.requestRefresh()
        try await waitUntil { await fixture.provider.hasPendingFetch(2) }
        fixture.defaults.set(ResourceUsageMode.normal.rawValue, forKey: ResourceUsageMode.storageKey)
        fixture.coordinator.resourcePolicyDidChange()
        await fixture.provider.finishFetch(2, with: .success(recoveryTrack("Fresh")))
        try await waitUntil { fixture.model.track?.title == "Fresh" && !fixture.model.isRefreshing }
        #expect(!fixture.coordinator.isSavingResources)
        #expect(try #require(fixture.coordinator.nextRefreshDate).timeIntervalSinceNow < 5)
        #expect(await fixture.provider.fetchCount == 2)
        #expect(fixture.defaults.bool(forKey: WidgetPreferences.outlineShimmerKey))
    }

    @Test("automatic follows Low Power Mode and resamples it on wake")
    func automaticResourcePolicy() async throws {
        var lowPower = false
        let fixture = RecoveryFixture(lowPowerMode: { lowPower })
        defer { fixture.stop() }
        fixture.coordinator.start()
        try await waitUntil { await fixture.provider.hasPendingFetch(1) }
        lowPower = true
        fixture.coordinator.resourcePolicyDidChange()
        #expect(fixture.coordinator.isSavingResources)
        await fixture.provider.finishFetch(1, with: .failure(SpotifyPlaybackError.automationDenied))
        try await waitUntil { fixture.model.availability == .automationDenied && !fixture.model.isRefreshing }
        lowPower = false
        fixture.coordinator.resourcePolicyDidChange()
        #expect(fixture.coordinator.nextRefreshDate == nil)
        #expect(!fixture.coordinator.isSavingResources)
        fixture.coordinator.suspendForSleep()
        lowPower = true
        fixture.coordinator.resourcePolicyDidChange()
        #expect(fixture.coordinator.nextRefreshDate == nil)
        fixture.coordinator.resumeAfterWake()
        try await waitUntil { await fixture.provider.hasPendingFetch(2) }
        #expect(fixture.coordinator.isSavingResources)
        await fixture.provider.finishFetch(2, with: .success(recoveryTrack("Awake")))
        try await waitUntil { fixture.model.track?.title == "Awake" }
    }

    @Test("denied permission leaves no schedule and manual recovery resumes polling")
    func permissionRecovery() async throws {
        let fixture = RecoveryFixture()
        defer { fixture.stop() }
        fixture.coordinator.start()
        try await waitUntil { await fixture.provider.hasPendingFetch(1) }
        await fixture.provider.finishFetch(1, with: .failure(SpotifyPlaybackError.automationDenied))
        try await waitUntil { fixture.model.availability == .automationDenied && !fixture.model.isRefreshing }
        #expect(fixture.coordinator.nextRefreshDate == nil)

        fixture.coordinator.requestRefresh()
        try await waitUntil { await fixture.provider.hasPendingFetch(2) }
        await fixture.provider.finishFetch(2, with: .success(recoveryTrack("Recovered")))
        try await waitUntil { fixture.model.availability == .ready && !fixture.model.isRefreshing }
        #expect(fixture.model.track?.title == "Recovered")
        let scheduled = try #require(fixture.coordinator.nextRefreshDate)
        #expect(scheduled > Date())
        #expect(await fixture.provider.fetchCount == 2)
    }

    @Test("sleep cancels the schedule and ignores late reads while wake fetches fresh state")
    func sleepAndWake() async throws {
        let fixture = RecoveryFixture()
        defer { fixture.stop() }
        fixture.coordinator.start()
        try await waitUntil { await fixture.provider.hasPendingFetch(1) }
        await fixture.provider.finishFetch(1, with: .success(recoveryTrack("Before sleep")))
        try await waitUntil { fixture.coordinator.nextRefreshDate != nil }

        fixture.coordinator.requestRefresh()
        try await waitUntil { await fixture.provider.hasPendingFetch(2) }
        fixture.coordinator.suspendForSleep()
        #expect(fixture.coordinator.isSleeping)
        #expect(fixture.coordinator.nextRefreshDate == nil)
        #expect(!fixture.model.isRefreshing)
        #expect(fixture.model.isStale)
        await fixture.provider.finishFetch(2, with: .success(recoveryTrack("Obsolete")))
        try await waitUntil { await fixture.provider.completedFetches == 2 }
        #expect(fixture.model.track?.title == "Before sleep")
        #expect(fixture.coordinator.nextRefreshDate == nil)

        fixture.coordinator.resumeAfterWake()
        try await waitUntil { await fixture.provider.hasPendingFetch(3) }
        #expect(!fixture.coordinator.isSleeping)
        await fixture.provider.finishFetch(3, with: .success(recoveryTrack("After wake")))
        try await waitUntil { fixture.model.track?.title == "After wake" && !fixture.model.isRefreshing }
        #expect(!fixture.model.isStale)
        #expect(fixture.coordinator.nextRefreshDate != nil)
    }

    @Test("a stopped coordinator cannot be restarted by wake or a late read")
    func stopPreventsWakeRestart() async throws {
        let fixture = RecoveryFixture()
        defer { fixture.stop() }
        fixture.coordinator.start()
        try await waitUntil { await fixture.provider.hasPendingFetch(1) }
        fixture.coordinator.suspendForSleep()
        fixture.coordinator.stop()
        fixture.coordinator.resumeAfterWake()
        fixture.coordinator.requestRefresh()
        await fixture.provider.finishFetch(1, with: .success(recoveryTrack("Late")))
        try await waitUntil { await fixture.provider.completedFetches == 1 }
        #expect(await fixture.provider.fetchCount == 1)
        #expect(fixture.model.track == nil)
        #expect(!fixture.model.isRefreshing)
        #expect(fixture.coordinator.nextRefreshDate == nil)
    }

    @Test("changing the preferred source clears old state and rejects its pending snapshot")
    func sourceChangeRejectsOldSnapshot() async throws {
        let fixture = RecoveryFixture()
        defer { fixture.stop() }
        fixture.coordinator.start()
        try await waitUntil { await fixture.provider.hasPendingFetch(1) }
        await fixture.provider.finishFetch(1, with: .success(recoveryTrack("Spotify")))
        try await waitUntil { fixture.model.availability == .ready && !fixture.model.isRefreshing }
        fixture.coordinator.requestRefresh()
        try await waitUntil { await fixture.provider.hasPendingFetch(2) }

        fixture.defaults.set(MediaSourcePreference.appleMusic.rawValue, forKey: MediaSourcePreference.storageKey)
        fixture.coordinator.sourcePreferenceDidChange()
        #expect(fixture.model.track == nil)
        #expect(fixture.model.activeSource == nil)
        try await waitUntil { await fixture.provider.hasPendingFetch(3) }
        await fixture.provider.finishFetch(3, with: .success(recoveryTrack("Music", source: .appleMusic)))
        try await waitUntil { fixture.model.track?.title == "Music" && !fixture.model.isRefreshing }
        await fixture.provider.finishFetch(2, with: .success(recoveryTrack("Obsolete Spotify")))
        try await waitUntil { await fixture.provider.completedFetches == 3 }
        #expect(fixture.model.track?.title == "Music")
        #expect(fixture.model.activeSource == .appleMusic)
        #expect(fixture.coordinator.nextRefreshDate != nil)
    }

    @Test("lifecycle invalidation cancels a queued playback command before execution")
    func invalidationCancelsPendingCommand() async throws {
        let provider = RecoveryProvider()
        let model = SpotifySpikeModel(provider: provider)
        let refresh = Task { await model.refresh() }
        try await waitUntil { await provider.hasPendingFetch(1) }
        await provider.finishFetch(1, with: .success(recoveryTrack("Song")))
        await refresh.value

        let command = Task { await model.togglePlayback() }
        try await waitUntil { await provider.hasPendingCommand }
        #expect(model.isPerformingCommand)
        model.invalidate(clearTrack: true)
        await provider.finishCommand()
        await command.value
        #expect(await provider.commandWasCancelled)
        #expect(!(await provider.commandExecuted))
        #expect(!model.isPerformingCommand)
        #expect(model.track == nil)
        #expect(await provider.fetchCount == 1)
    }

    @Test("a late successful poll cannot undo permission denial from a playback command")
    func commandDenialRejectsOlderPoll() async throws {
        let fixture = RecoveryFixture()
        defer { fixture.stop() }
        fixture.coordinator.start()
        try await waitUntil { await fixture.provider.hasPendingFetch(1) }
        await fixture.provider.finishFetch(1, with: .success(recoveryTrack("Before denial")))
        try await waitUntil { fixture.model.availability == .ready && !fixture.model.isRefreshing }

        // Retain the caller so the final assertions run after the entire old
        // model refresh has finished, not only after its provider returns.
        let oldPoll = Task { await fixture.model.refresh() }
        try await waitUntil { await fixture.provider.hasPendingFetch(2) }
        await fixture.provider.setCommandError(SpotifyPlaybackError.automationDenied)
        await fixture.model.togglePlayback()
        #expect(fixture.model.availability == .automationDenied)
        #expect(fixture.coordinator.nextRefreshDate == nil)

        await fixture.provider.finishFetch(2, with: .success(recoveryTrack("Obsolete success")))
        await oldPoll.value
        #expect(fixture.model.availability == .automationDenied)
        #expect(fixture.model.track == nil)
        #expect(fixture.model.nextRefreshDelay == nil)
        #expect(fixture.coordinator.nextRefreshDate == nil)
        #expect(!fixture.model.isRefreshing)
    }

    @Test("a successful command drains an overlapping poll without canceling or publishing it", arguments: [false, true])
    func commandDrainsOlderPoll(oldReadFails: Bool) async throws {
        try await withCommandRecoveryModel { model, provider in
            var publishedStates: [(String?, PlaybackAvailability)] = []
            model.onRefreshCompleted = {
                publishedStates.append((model.track?.title, model.availability))
            }
            let oldPoll = Task { await model.refresh() }
            try await waitUntil { await provider.hasPendingFetch(2) }
            let command = Task { await model.togglePlayback() }
            try await waitUntil { await provider.hasPendingCommand }
            await provider.finishCommand()
            try await waitUntil { await provider.commandExecuted }
            // Let the command continuation run while the old read remains
            // explicitly held by the fake; no wall-clock delay is needed.
            for _ in 0 ..< 20 { await Task.yield() }

            if oldReadFails {
                await provider.finishFetch(2, with: .failure(SpotifyPlaybackError.automationDenied))
            } else {
                await provider.finishFetch(2, with: .success(recoveryTrack("Obsolete pre-command snapshot")))
            }
            await oldPoll.value
            #expect(!(await provider.cancelledFetches.contains(2)))
            try await waitUntil { await provider.hasPendingFetch(3) }
            #expect(model.track?.title == "Before command")
            #expect(model.availability == .ready)
            #expect(model.consecutiveFailures == 0)
            #expect(publishedStates.allSatisfy { $0.0 == "Before command" && $0.1 == .ready })

            await provider.finishFetch(3, with: .success(recoveryTrack("Fresh post-command snapshot")))
            await command.value
            #expect(model.track?.title == "Fresh post-command snapshot")
            #expect(model.availability == .ready)
            #expect(!model.isRefreshing)
            #expect(!model.isPerformingCommand)
            #expect(await provider.fetchCount == 3)
            #expect(publishedStates.last?.0 == "Fresh post-command snapshot")
        }
    }

    @Test("lifecycle invalidation while a command drains a poll prevents its follow-up refresh")
    func invalidationWhileCommandDrainsPollWins() async throws {
        try await withCommandRecoveryModel { model, provider in
            let oldPoll = Task { await model.refresh() }
            try await waitUntil { await provider.hasPendingFetch(2) }
            var commandFinished = false
            let command = Task {
                await model.togglePlayback()
                commandFinished = true
            }
            try await waitUntil { await provider.hasPendingCommand }
            await provider.finishCommand()
            try await waitUntil { await provider.commandExecuted }
            for _ in 0 ..< 20 { await Task.yield() }

            model.invalidate(clearTrack: true)
            await provider.finishFetch(2, with: .success(recoveryTrack("Obsolete before invalidation")))
            await oldPoll.value
            try await waitUntil {
                if commandFinished { return true }
                return await provider.hasPendingFetch(3)
            }
            // Release an incorrectly started read too, so a regression fails
            // by assertion instead of leaving a checked continuation suspended.
            await provider.finishFetch(3, with: .success(recoveryTrack("Obsolete follow-up")))
            await command.value
            #expect(await provider.fetchCount == 2)
            #expect(model.track == nil)
            #expect(model.activeSource == nil)
            #expect(model.availability == .loading)
            #expect(!model.isRefreshing)
            #expect(!model.isPerformingCommand)
        }
    }

    private func withCommandRecoveryModel(
        _ body: (SpotifySpikeModel, RecoveryProvider) async throws -> Void
    ) async throws {
        let provider = RecoveryProvider()
        let model = SpotifySpikeModel(provider: provider)
        do {
            let initial = Task { await model.refresh() }
            try await waitUntil { await provider.hasPendingFetch(1) }
            await provider.finishFetch(1, with: .success(recoveryTrack("Before command")))
            await initial.value
            try await body(model, provider)
        } catch {
            model.onRefreshCompleted = nil
            model.invalidate(clearTrack: true)
            await provider.finishAllPending()
            throw error
        }
        model.onRefreshCompleted = nil
        model.invalidate(clearTrack: true)
        await provider.finishAllPending()
    }
}

@MainActor
private struct RecoveryFixture {
    let suiteName: String
    let defaults: UserDefaults
    let provider: RecoveryProvider
    let model: SpotifySpikeModel
    let coordinator: PlaybackCoordinator

    init(lowPowerMode: @escaping () -> Bool = { false }) {
        let suiteName = "TrackPeek.PlaybackRecoveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(MediaSourcePreference.spotify.rawValue, forKey: MediaSourcePreference.storageKey)
        let provider = RecoveryProvider()
        let model = SpotifySpikeModel(provider: provider)
        self.suiteName = suiteName
        self.defaults = defaults
        self.provider = provider
        self.model = model
        coordinator = PlaybackCoordinator(model: model, defaults: defaults, observesSystemEvents: false, lowPowerMode: lowPowerMode)
    }

    func stop() {
        coordinator.stop()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private func recoveryTrack(_ title: String, source: PlaybackSource = .spotify) -> SpotifyTrack {
    SpotifyTrack(title: title, artist: "Artist", duration: 120, position: 20, isPlaying: false, source: source)
}

@MainActor
private func waitUntil(_ predicate: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !(await predicate()), ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(await predicate(), "Expected lifecycle state within two seconds")
}

/// Holds each read independently so old source responses can finish after newer
/// ones. Cancellation deliberately does not finish a read, matching native I/O.
private actor RecoveryProvider: SpotifyPlaybackProviding {
    private var pendingFetches: [Int: CheckedContinuation<SpotifyTrack, any Error>] = [:]
    private var pendingCommand: CheckedContinuation<Void, Never>?
    private var commandError: (any Error)?
    private(set) var fetchCount = 0
    private(set) var completedFetches = 0
    private(set) var commandWasCancelled = false
    private(set) var commandExecuted = false
    private(set) var cancelledFetches: Set<Int> = []
    var hasPendingCommand: Bool { pendingCommand != nil }

    func hasPendingFetch(_ number: Int) -> Bool { pendingFetches[number] != nil }

    func fetchCurrentTrack() async throws -> SpotifyTrack {
        fetchCount += 1
        let number = fetchCount
        defer {
            completedFetches += 1
            if Task.isCancelled { cancelledFetches.insert(number) }
        }
        return try await withCheckedThrowingContinuation { pendingFetches[number] = $0 }
    }

    func finishFetch(_ number: Int, with result: Result<SpotifyTrack, any Error>) {
        pendingFetches.removeValue(forKey: number)?.resume(with: result)
    }

    func activeSource() -> PlaybackSource { .spotify }

    func setCommandError(_ error: any Error) { commandError = error }

    func playPause() async throws {
        if let commandError { throw commandError }
        await withCheckedContinuation { pendingCommand = $0 }
        commandWasCancelled = Task.isCancelled
        try Task.checkCancellation()
        commandExecuted = true
    }

    func finishCommand() {
        pendingCommand?.resume()
        pendingCommand = nil
    }

    func finishAllPending() {
        let fetches = pendingFetches.values
        pendingFetches.removeAll()
        for fetch in fetches { fetch.resume(throwing: CancellationError()) }
        finishCommand()
    }

    func nextTrack() throws { }
    func previousTrack() throws { }
    func seek(to position: TimeInterval) throws { }
    func setShuffle(_ enabled: Bool) throws { }
    func setRepeat(_ mode: RepeatMode) throws { }
    func setVolume(_ volume: Int) throws { }
}

@Suite("Playback diagnostic report")
struct PlaybackDiagnosticsTests {
    @Test("report uses technical states and explains denied permission")
    func deniedReport() {
        let diagnostics = PlaybackDiagnostics(
            source: .appleMusic, availability: .automationDenied, isStale: false,
            isSleeping: false, lastSuccessfulRefresh: nil, nextRefreshDate: nil,
            audioStatus: .paused
        )
        let report = diagnostics.report(version: "1.0", build: "1")
        #expect(report.contains("Music"))
        #expect(report.contains("Доступ запрещён"))
        #expect(report.contains("Проверить снова"))
        #expect(!report.contains("/Users/"))
    }

    @Test("stale snapshots are not presented as a connected player")
    func staleReport() {
        let diagnostics = PlaybackDiagnostics(
            source: .spotify, availability: .unavailable, isStale: true,
            isSleeping: false, lastSuccessfulRefresh: Date(timeIntervalSince1970: 100),
            nextRefreshDate: Date(timeIntervalSince1970: 200), audioStatus: .notNeeded
        )
        let report = diagnostics.report(version: "1.0", build: "1")
        #expect(report.contains("показан последний трек"))
        #expect(report.contains("нет видимого потребителя"))
        #expect(!report.contains("Подключён"))
    }
}

@Suite("Resource policy")
struct ResourcePolicyTests {
    @Test("explicit modes override the system and automatic follows it")
    func modes() {
        #expect(ResourceUsageMode.automatic.isSaving(lowPowerMode: true))
        #expect(!ResourceUsageMode.automatic.isSaving(lowPowerMode: false))
        #expect(!ResourceUsageMode.normal.isSaving(lowPowerMode: true))
        #expect(ResourceUsageMode.economical.isSaving(lowPowerMode: false))
    }

    @Test("saving slows healthy polling without changing recovery or denied permission")
    func delays() {
        #expect(ResourceUsageMode.pollDelay(2, availability: .ready, saving: true) == 5)
        #expect(ResourceUsageMode.pollDelay(4, availability: .ready, saving: true) == 8)
        #expect(ResourceUsageMode.pollDelay(2, availability: .ready, saving: false) == 2)
        #expect(ResourceUsageMode.pollDelay(nil, availability: .automationDenied, saving: true) == nil)
    }
}
