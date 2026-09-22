import Foundation
import Observation

@Observable
@MainActor
final class SpotifySpikeModel {
    private let provider: any SpotifyPlaybackProviding

    private(set) var track: SpotifyTrack?
    private(set) var statusText = "Обновление…"
    private(set) var snapshotDate = Date()
    private(set) var availability: PlaybackAvailability = .loading
    /// Реально резолвнутый источник — не гадаем по сохранённой preference,
    /// потому что в режиме «Автоматически» она не говорит, что играет сейчас.
    private(set) var activeSource: PlaybackSource?

    /// После нашего seek AppleScript какое-то время может возвращать старую
    /// позицию — до этого момента доверяем оптимистичной локальной позиции.
    private var seekSettlingDeadline: Date?
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored var onRefreshCompleted: (() -> Void)?
    @ObservationIgnored private var commandTask: Task<Void, Never>?
    @ObservationIgnored private var commandID = UUID()
    private(set) var isPerformingCommand = false
    private(set) var isRefreshing = false
    private(set) var lastSuccessfulRefresh: Date?
    private(set) var consecutiveFailures = 0

    var isStale: Bool { track != nil && availability != .ready }

    var nextRefreshDelay: TimeInterval? {
        switch availability {
        case .automationDenied: nil
        case .spotifyNotRunning: 30
        case .unavailable: min(pow(2, Double(min(max(consecutiveFailures, 1), 5))), 30)
        case .ready: track?.isPlaying == true ? 2 : 4
        case .nothingPlaying, .loading: 4
        }
    }

    deinit {
        refreshTask?.cancel()
        commandTask?.cancel()
    }

    init(provider: any SpotifyPlaybackProviding = PlaybackSourceRouter()) {
        self.provider = provider
    }

    var activeSourceDisplayName: String {
        activeSource?.displayName ?? "Плеер"
    }

    var capabilities: PlaybackCapabilities {
        activeSource.map(PlaybackCapabilities.capabilities(for:)) ?? []
    }

    var secondary: PlaybackSecondaryState? {
        track?.secondary
    }

    /// UI, timer and controls share one pending read. Explicit lifecycle changes
    /// can invalidate it; a late native result then cannot change the new state.
    func refresh(replacingCurrent: Bool = false) async {
        guard !Task.isCancelled else { return }
        if !replacingCurrent, let refreshTask {
            await refreshTask.value
            return
        }
        refreshTask?.cancel()
        refreshGeneration &+= 1
        let generation = refreshGeneration
        isRefreshing = true
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh(generation: generation)
        }
        refreshTask = task
        await task.value
    }

    func invalidate(clearTrack: Bool = false) {
        cancelCommand()
        cancelRefresh()
        consecutiveFailures = 0
        seekSettlingDeadline = nil
        if clearTrack {
            track = nil
            activeSource = nil
            lastSuccessfulRefresh = nil
            availability = .loading
            statusText = "Обновление…"
        } else {
            freezeSnapshot()
            availability = .unavailable
            statusText = "Связь с плеером восстанавливается"
        }
    }

    private func cancelRefresh() {
        refreshGeneration &+= 1
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
    }

    private func performRefresh(generation: Int) async {
        defer {
            if generation == refreshGeneration {
                refreshTask = nil
                isRefreshing = false
                onRefreshCompleted?()
            }
        }
        let resolvedSource = await provider.activeSource()
        guard generation == refreshGeneration, !Task.isCancelled else { return }
        // Never present old-source artwork alongside controls for a new source.
        if let activeSource, activeSource != resolvedSource {
            cancelCommand()
            track = nil
        }
        activeSource = resolvedSource

        do {
            let fetched = try await provider.fetchCurrentTrack()
            guard generation == refreshGeneration, !Task.isCancelled else { return }
            if let source = fetched.source, source != activeSource { cancelCommand() }
            activeSource = fetched.source ?? activeSource
            lastSuccessfulRefresh = Date()
            consecutiveFailures = 0

            guard !fetched.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                track = nil
                seekSettlingDeadline = nil
                availability = .nothingPlaying
                statusText = "Ничего не воспроизводится"
                return
            }

            let now = Date()
            track = reconciled(fetched, now: now)
            snapshotDate = now
            availability = .ready
            statusText = fetched.isPlaying ? "Играет" : "На паузе"
        } catch {
            guard generation == refreshGeneration, !Task.isCancelled else { return }
            handleFailure(error)
        }
    }

    private func handleFailure(_ error: Error) {
        cancelCommand()
        consecutiveFailures = min(consecutiveFailures + 1, 30)
        seekSettlingDeadline = nil
        switch error {
        case SpotifyPlaybackError.automationDenied:
            track = nil
            availability = .automationDenied
            statusText = SpotifyPlaybackError.automationDenied.localizedDescription
        case SpotifyPlaybackError.spotifyNotRunning:
            track = nil
            availability = .spotifyNotRunning
            statusText = "\(activeSourceDisplayName) не запущен."
        default:
            freezeSnapshot()
            availability = .unavailable
            statusText = error.localizedDescription
        }
    }

    private func freezeSnapshot() {
        guard let current = track else { return }
        let now = Date()
        let position = PlaybackPositionResolver.livePosition(
            snapshotPosition: current.position, snapshotDate: snapshotDate,
            now: now, duration: current.duration, isPlaying: current.isPlaying
        )
        track = current.withPosition(position).withPlaybackStopped()
        snapshotDate = now
    }

    func togglePlayback() async {
        let provider = provider
        await performCommand { try await provider.playPause() }
    }

    func nextTrack() async {
        let provider = provider
        await performCommand { try await provider.nextTrack() }
    }

    func previousTrack() async {
        let provider = provider
        await performCommand { try await provider.previousTrack() }
    }

    func seek(to requestedPosition: TimeInterval) async {
        guard let track, requestedPosition.isFinite else { return }
        let position = min(max(requestedPosition, 0), track.duration)
        let provider = provider
        await performCommand(seekPosition: position) { try await provider.seek(to: position) }
    }

    func setShuffle(_ enabled: Bool) async {
        let provider = provider
        await performCommand { try await provider.setShuffle(enabled) }
    }

    func setRepeat(_ mode: RepeatMode) async {
        let provider = provider
        await performCommand { try await provider.setRepeat(mode) }
    }

    func setVolume(_ volume: Int) async {
        let provider = provider
        await performCommand { try await provider.setVolume(volume) }
    }

    private func cancelCommand() {
        commandID = UUID()
        commandTask?.cancel()
        commandTask = nil
        isPerformingCommand = false
    }

    private func performCommand(
        seekPosition: TimeInterval? = nil,
        operation: @escaping @Sendable () async throws -> Void
    ) async {
        guard availability == .ready, commandTask == nil, !Task.isCancelled else { return }
        let originalTrack = track
        let id = UUID()
        commandID = id
        isPerformingCommand = true
        let task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                try await operation()
                guard let self, self.commandID == id, !Task.isCancelled else { return }
                if let seekPosition, let track = self.track,
                   track.title == originalTrack?.title, track.artist == originalTrack?.artist,
                   track.album == originalTrack?.album, track.source == originalTrack?.source {
                    self.track = track.withPosition(seekPosition)
                    self.snapshotDate = Date()
                    self.seekSettlingDeadline = Date().addingTimeInterval(2)
                } else {
                    await self.refresh(replacingCurrent: true)
                }
            } catch {
                guard let self, self.commandID == id, !Task.isCancelled else { return }
                // A read started before the failed command must not restore
                // ready state after a newer denial/timeout.
                self.cancelRefresh()
                self.handleFailure(error)
                self.onRefreshCompleted?()
            }
            if let self, self.commandID == id {
                self.commandTask = nil
                self.isPerformingCommand = false
            }
        }
        commandTask = task
        await task.value
    }

    private func reconciled(_ fetched: SpotifyTrack, now: Date) -> SpotifyTrack {
        guard
            let current = track,
            current.source == fetched.source,
            current.title == fetched.title,
            current.artist == fetched.artist,
            abs(current.duration - fetched.duration) < 1,
            current.isPlaying,
            fetched.isPlaying
        else {
            seekSettlingDeadline = nil
            return fetched
        }

        let predicted = PlaybackPositionResolver.livePosition(
            snapshotPosition: current.position,
            snapshotDate: snapshotDate,
            now: now,
            duration: current.duration,
            isPlaying: true
        )
        let isSeekSettling = seekSettlingDeadline.map { now < $0 } ?? false
        if !isSeekSettling {
            seekSettlingDeadline = nil
        }

        let position = PlaybackPositionResolver.reconciledPosition(
            fetched: fetched.position,
            predicted: predicted,
            isSeekSettling: isSeekSettling
        )

        return fetched.withPosition(position)
    }
}
