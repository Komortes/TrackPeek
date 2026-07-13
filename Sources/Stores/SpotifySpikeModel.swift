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

    init(provider: any SpotifyPlaybackProviding = SpotifyAppleScriptClient()) {
        self.provider = provider
    }

    func refresh() {
        do {
            let track = try provider.fetchCurrentTrack()

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

    func togglePlayback() {
        do {
            try provider.playPause()
            refresh()
        } catch {
            statusText = error.localizedDescription
        }
    }

    func nextTrack() {
        do {
            try provider.nextTrack()
            refresh()
        } catch {
            statusText = error.localizedDescription
        }
    }

    func previousTrack() {
        do {
            try provider.previousTrack()
            refresh()
        } catch {
            statusText = error.localizedDescription
        }
    }

    func seek(to requestedPosition: TimeInterval) {
        guard let track else {
            return
        }

        let position = min(max(requestedPosition, 0), track.duration)

        do {
            try provider.seek(to: position)
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
