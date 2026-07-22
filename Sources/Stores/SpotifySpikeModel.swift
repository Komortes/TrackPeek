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

    init(provider: any SpotifyPlaybackProviding = PlaybackSourceRouter()) {
        self.provider = provider
    }

    func refresh() async {
        do {
            let track = try await provider.fetchCurrentTrack()

            guard !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.track = nil
                availability = .nothingPlaying
                statusText = "Ничего не воспроизводится"
                return
            }

            self.track = track
            snapshotDate = Date()
            availability = .ready
            statusText = track.isPlaying ? "Играет" : "На паузе"
        } catch SpotifyPlaybackError.spotifyNotRunning {
            track = nil
            availability = .spotifyNotRunning
            statusText = SpotifyPlaybackError.spotifyNotRunning.localizedDescription
        } catch {
            track = nil
            availability = .unavailable
            statusText = error.localizedDescription
        }
    }

    func togglePlayback() async {
        do {
            try await provider.playPause()
            await refresh()
        } catch {
            statusText = error.localizedDescription
        }
    }

    func nextTrack() async {
        do {
            try await provider.nextTrack()
            await refresh()
        } catch {
            statusText = error.localizedDescription
        }
    }

    func previousTrack() async {
        do {
            try await provider.previousTrack()
            await refresh()
        } catch {
            statusText = error.localizedDescription
        }
    }

    func seek(to requestedPosition: TimeInterval) async {
        guard let track else {
            return
        }

        let position = min(max(requestedPosition, 0), track.duration)

        do {
            try await provider.seek(to: position)
            self.track = SpotifyTrack(
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration,
                position: position,
                artworkURL: track.artworkURL,
                isPlaying: track.isPlaying
            )
            snapshotDate = Date()
        } catch {
            statusText = error.localizedDescription
        }
    }
}
