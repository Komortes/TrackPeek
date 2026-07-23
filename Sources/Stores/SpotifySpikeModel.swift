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

    /// После нашего seek AppleScript какое-то время может возвращать старую
    /// позицию — до этого момента доверяем оптимистичной локальной позиции.
    private var seekSettlingDeadline: Date?

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

            let now = Date()
            self.track = reconciled(track, now: now)
            snapshotDate = now
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
            seekSettlingDeadline = Date().addingTimeInterval(2)
        } catch {
            statusText = error.localizedDescription
        }
    }

    private func reconciled(_ fetched: SpotifyTrack, now: Date) -> SpotifyTrack {
        guard
            let current = track,
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

        return SpotifyTrack(
            title: fetched.title,
            artist: fetched.artist,
            album: fetched.album,
            duration: fetched.duration,
            position: position,
            artworkURL: fetched.artworkURL,
            isPlaying: fetched.isPlaying
        )
    }
}
