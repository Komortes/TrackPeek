import Foundation
import Observation

@Observable
@MainActor
final class LyricsStore {
    enum State: Equatable {
        case loading
        case unavailable
        case failed
        case loaded(TrackLyrics)
    }

    private let provider: any LyricsProviding
    private var cache: [LyricsRequest: State] = [:]
    private var cacheOrder: [LyricsRequest] = []
    @ObservationIgnored private var task: Task<Void, Never>?
    private var activeRequest: LyricsRequest?
    private let maximumCacheEntries = 48
    private var timingRequest: LyricsRequest?
    private var timingSource: PlaybackSource?
    private var timingOffset: TimeInterval = 0

    func currentTrackDidChange(_ track: SpotifyTrack?) {
        let request = track.map(LyricsRequest.init(track:))
        if let activeRequest, activeRequest != request {
            cancelPendingRequest()
        }
        guard request != timingRequest || track?.source != timingSource else { return }
        timingRequest = request
        timingSource = track?.source
        timingOffset = 0
    }

    func offset(for track: SpotifyTrack) -> TimeInterval {
        timingRequest == LyricsRequest(track: track) && timingSource == track.source ? timingOffset : 0
    }

    /// Positive means show words earlier. One current-track value in memory;
    /// never a per-song history or a persisted preference.
    func setOffset(_ value: TimeInterval, for track: SpotifyTrack) {
        guard value.isFinite else { return }
        currentTrackDidChange(track)
        timingOffset = min(max(value, -10), 10)
    }

    func isLoading(for track: SpotifyTrack) -> Bool {
        activeRequest == LyricsRequest(track: track)
    }

    func retry(for track: SpotifyTrack) {
        let request = LyricsRequest(track: track)
        guard activeRequest != request else { return }
        switch cache[request] {
        case .unavailable, .failed, nil:
            cache.removeValue(forKey: request)
            cacheOrder.removeAll { $0 == request }
            prepare(for: track)
        default: break
        }
    }

    deinit { task?.cancel() }

    init(provider: any LyricsProviding = LRCLibLyricsClient()) {
        self.provider = provider
    }

    /// Чистое чтение — безопасно вызывать из body.
    func state(for track: SpotifyTrack) -> State {
        cache[LyricsRequest(track: track)] ?? .loading
    }

    /// Запускает загрузку текста, если её ещё не было; вызывать из .task.
    func prepare(for track: SpotifyTrack) {
        guard !Task.isCancelled else { return }
        let request = LyricsRequest(track: track)
        guard activeRequest != request else { return }
        cancelPendingRequest()
        guard cache[request] == nil || cache[request] == .failed else { return }

        cache.removeValue(forKey: request)
        cacheOrder.removeAll { $0 == request }
        activeRequest = request
        let provider = provider
        task = Task { [weak self] in
            let state: State
            do {
                if let lyrics = try await provider.fetchLyrics(for: request) {
                    state = .loaded(lyrics)
                } else {
                    state = .unavailable
                }
            } catch {
                state = .failed
            }

            guard !Task.isCancelled, let self, activeRequest == request else { return }
            cache[request] = state
            cacheOrder.removeAll { $0 == request }
            cacheOrder.append(request)
            while cacheOrder.count > maximumCacheEntries {
                let evicted = cacheOrder.removeFirst()
                cache.removeValue(forKey: evicted)
            }
            activeRequest = nil
            task = nil
        }
    }

    private func cancelPendingRequest() {
        task?.cancel()
        task = nil
        activeRequest = nil
    }
}
