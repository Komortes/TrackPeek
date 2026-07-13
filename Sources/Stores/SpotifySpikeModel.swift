import Foundation
import Observation

@Observable
@MainActor
final class SpotifySpikeModel {
    private let provider: any SpotifyPlaybackProviding

    private(set) var track: SpotifyTrack?
    private(set) var statusText = "Обновление…"

    init(provider: any SpotifyPlaybackProviding = SpotifyAppleScriptClient()) {
        self.provider = provider
    }

    func refresh() {
        do {
            let track = try provider.fetchCurrentTrack()
            self.track = track
            statusText = track.isPlaying ? "Играет" : "На паузе"
        } catch {
            track = nil
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
}
