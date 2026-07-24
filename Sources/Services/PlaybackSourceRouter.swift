import AppKit
import Foundation

/// Picks between the Spotify and Apple Music AppleScript clients per call,
/// so switching the "Источник" preference takes effect on the very next
/// poll without recreating the model or its provider.
///
/// В режиме «Автоматически» источник выбирается по реальному состоянию:
/// 1) кто сейчас воспроизводит музыку; 2) последний активный источник;
/// 3) запущенное приложение. Команды управления идут в тот же источник,
/// чей снапшот показывается.
actor PlaybackSourceRouter: SpotifyPlaybackProviding {
    private let spotify: any SpotifyPlaybackProviding
    private let appleMusic: any SpotifyPlaybackProviding

    /// Последний источник, отдавший валидный снапшот в режиме auto.
    private var lastActiveSource: PlaybackSource?

    init(
        spotify: any SpotifyPlaybackProviding = SpotifyAppleScriptClient(),
        appleMusic: any SpotifyPlaybackProviding = MusicAppleScriptClient()
    ) {
        self.spotify = spotify
        self.appleMusic = appleMusic
    }

    func fetchCurrentTrack() async throws -> SpotifyTrack {
        switch preference {
        case .spotify:
            return try await spotify.fetchCurrentTrack().tagged(with: .spotify)
        case .appleMusic:
            return try await appleMusic.fetchCurrentTrack().tagged(with: .appleMusic)
        case .auto:
            return try await fetchAutoTrack()
        }
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

    private func fetchAutoTrack() async throws -> SpotifyTrack {
        let primary = candidateOrder().first!
        let secondary: PlaybackSource = primary == .spotify ? .appleMusic : .spotify

        let primaryResult: Result<SpotifyTrack, Error>
        do {
            primaryResult = .success(try await provider(for: primary).fetchCurrentTrack())
        } catch {
            primaryResult = .failure(error)
        }

        if case let .success(track) = primaryResult, track.isPlaying {
            lastActiveSource = primary
            return track.tagged(with: primary)
        }

        // Основной кандидат молчит — проверяем второго, но только если его
        // приложение уже запущено (AppleScript иначе может его запустить).
        if isRunning(secondary.bundleIdentifier),
           let track = try? await provider(for: secondary).fetchCurrentTrack(),
           track.isPlaying {
            lastActiveSource = secondary
            return track.tagged(with: secondary)
        }

        switch primaryResult {
        case let .success(track):
            lastActiveSource = primary
            return track.tagged(with: primary)
        case let .failure(error):
            // Второй источник может быть на паузе, но живым.
            if isRunning(secondary.bundleIdentifier),
               let track = try? await provider(for: secondary).fetchCurrentTrack() {
                lastActiveSource = secondary
                return track.tagged(with: secondary)
            }
            throw error
        }
    }

    private func candidateOrder() -> [PlaybackSource] {
        if let lastActiveSource {
            return [lastActiveSource]
        }
        if isRunning(PlaybackSource.spotify.bundleIdentifier) {
            return [.spotify]
        }
        if isRunning(PlaybackSource.appleMusic.bundleIdentifier) {
            return [.appleMusic]
        }
        return [.spotify]
    }

    private func provider(for source: PlaybackSource) -> any SpotifyPlaybackProviding {
        switch source {
        case .spotify: spotify
        case .appleMusic: appleMusic
        }
    }

    func activeSource() -> PlaybackSource {
        switch preference {
        case .spotify:
            .spotify
        case .appleMusic:
            .appleMusic
        case .auto:
            lastActiveSource ?? candidateOrder().first!
        }
    }

    private func activeProvider() -> any SpotifyPlaybackProviding {
        switch preference {
        case .spotify:
            spotify
        case .appleMusic:
            appleMusic
        case .auto:
            provider(for: lastActiveSource ?? candidateOrder().first!)
        }
    }

    private var preference: MediaSourcePreference {
        let stored = UserDefaults.standard.string(forKey: MediaSourcePreference.storageKey)
        return stored.flatMap(MediaSourcePreference.init) ?? MediaSourcePreference.fallback
    }

    private nonisolated func isRunning(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleIdentifier
        }
    }
}
