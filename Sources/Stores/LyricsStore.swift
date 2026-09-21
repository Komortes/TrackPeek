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
        task?.cancel()
        task = nil
        activeRequest = nil
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
}
