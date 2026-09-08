import Foundation
import Observation

@Observable
@MainActor
final class LyricsStore {
    enum State: Equatable {
        case loading
        case unavailable
        case loaded(TrackLyrics)
    }

    private let provider: any LyricsProviding
    private var cache: [LyricsRequest: State] = [:]
    private var cacheOrder: [LyricsRequest] = []
    private var retryableRequests: Set<LyricsRequest> = []
    @ObservationIgnored private var task: Task<Void, Never>?
    private var activeRequest: LyricsRequest?
    private let maximumCacheEntries = 48

    deinit { task?.cancel() }

    init(provider: any LyricsProviding = LRCLibLyricsClient()) {
        self.provider = provider
    }

    /// Чистое чтение — безопасно вызывать из body.
    func state(for track: SpotifyTrack) -> State {
        cache[request(for: track)] ?? .loading
    }

    /// Запускает загрузку текста, если её ещё не было; вызывать из .task.
    func prepare(for track: SpotifyTrack) {
        let request = request(for: track)
        guard activeRequest != request else { return }
        task?.cancel()
        task = nil
        activeRequest = nil
        guard cache[request] == nil || retryableRequests.contains(request) else { return }

        activeRequest = request
        let provider = provider
        task = Task { [weak self] in
            let state: State
            var shouldRetry = false
            do {
                if let lyrics = try await provider.fetchLyrics(for: request) {
                    state = .loaded(lyrics)
                } else {
                    state = .unavailable
                }
            } catch {
                state = .unavailable
                shouldRetry = true
            }

            guard !Task.isCancelled, let self else { return }
            cache[request] = state
            if shouldRetry {
                retryableRequests.insert(request)
            } else {
                retryableRequests.remove(request)
            }
            cacheOrder.removeAll { $0 == request }
            cacheOrder.append(request)
            while cacheOrder.count > maximumCacheEntries {
                let evicted = cacheOrder.removeFirst()
                cache.removeValue(forKey: evicted)
                retryableRequests.remove(evicted)
            }
            activeRequest = nil
            task = nil
        }
    }

    private func request(for track: SpotifyTrack) -> LyricsRequest {
        LyricsRequest(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration
        )
    }
}
