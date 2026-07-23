import AppKit
import Foundation

/// Picks between the Spotify and Apple Music AppleScript clients per call,
/// so switching the "Источник" preference takes effect on the very next
/// poll without recreating the model or its provider.
actor PlaybackSourceRouter: SpotifyPlaybackProviding {
    private let spotify: any SpotifyPlaybackProviding
    private let appleMusic: any SpotifyPlaybackProviding

    init(
        spotify: any SpotifyPlaybackProviding = SpotifyAppleScriptClient(),
        appleMusic: any SpotifyPlaybackProviding = MusicAppleScriptClient()
    ) {
        self.spotify = spotify
        self.appleMusic = appleMusic
    }

    func fetchCurrentTrack() async throws -> SpotifyTrack {
        try await activeProvider().fetchCurrentTrack()
    }

    func playPause() async throws {
        try await activeProvider().playPause()
    }

    func nextTrack() async throws {
        try await activeProvider().nextTrack()
    }

    func previousTrack() async throws {
        try await activeProvider().previousTrack()
    }

    func seek(to position: TimeInterval) async throws {
        try await activeProvider().seek(to: position)
    }

    private func activeProvider() -> any SpotifyPlaybackProviding {
        switch preference {
        case .spotify:
            spotify
        case .appleMusic:
            appleMusic
        case .auto:
            isRunning("com.spotify.client") || !isRunning("com.apple.Music")
                ? spotify
                : appleMusic
        }
    }

    private var preference: MediaSourcePreference {
        let stored = UserDefaults.standard.string(forKey: MediaSourcePreference.storageKey)
        return stored.flatMap(MediaSourcePreference.init) ?? MediaSourcePreference.fallback
    }

    private func isRunning(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleIdentifier
        }
    }
}
