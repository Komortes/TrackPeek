import AppKit

enum PlayerAppLauncher {
    /// Opens whichever app the current "Источник" preference resolves to,
    /// so the artwork/menu "open" actions match what TrackPeek is actually
    /// showing instead of always assuming Spotify.
    @MainActor
    static func openActiveSource() {
        let stored = UserDefaults.standard.string(forKey: MediaSourcePreference.storageKey)
        let preference = stored.flatMap(MediaSourcePreference.init) ?? MediaSourcePreference.fallback
        let runningApps = NSWorkspace.shared.runningApplications
        let source = sourceToOpen(
            preference: preference,
            resolvedSource: PlaybackCoordinator.shared.model.activeSource,
            spotifyRunning: runningApps.contains { $0.bundleIdentifier == PlaybackSource.spotify.bundleIdentifier },
            musicRunning: runningApps.contains { $0.bundleIdentifier == PlaybackSource.appleMusic.bundleIdentifier }
        )
        open(bundleIdentifier: source.bundleIdentifier)
    }

    static func sourceToOpen(
        preference: MediaSourcePreference,
        resolvedSource: PlaybackSource?,
        spotifyRunning: Bool,
        musicRunning: Bool
    ) -> PlaybackSource {
        switch preference {
        case .spotify:
            .spotify
        case .appleMusic:
            .appleMusic
        case .auto:
            resolvedSource ?? (spotifyRunning || !musicRunning ? .spotify : .appleMusic)
        }
    }

    private static func open(bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return
        }

        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}
