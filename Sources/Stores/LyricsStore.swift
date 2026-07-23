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
    private var tasks: [LyricsRequest: Task<Void, Never>] = [:]

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
        guard cache[request] == nil, tasks[request] == nil else { return }

        tasks[request] = Task { [weak self] in
            let state: State
            do {
                if let lyrics = try await self?.provider.fetchLyrics(for: request) {
                    state = .loaded(lyrics)
                } else {
                    state = .unavailable
                }
            } catch {
                // Сетевой сбой: не считаем «текста нет навсегда», просто
                // не кэшируем успех; повторная попытка — при новом prepare.
                state = .unavailable
            }

            guard !Task.isCancelled else { return }
            self?.cache[request] = state
            self?.tasks[request] = nil
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
