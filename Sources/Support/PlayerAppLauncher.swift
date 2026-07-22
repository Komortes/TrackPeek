import AppKit

enum PlayerAppLauncher {
    /// Opens whichever app the current "Источник" preference resolves to,
    /// so the artwork/menu "open" actions match what TrackPeek is actually
    /// showing instead of always assuming Spotify.
    static func openActiveSource() {
        let stored = UserDefaults.standard.string(forKey: MediaSourcePreference.storageKey)
        let preference = stored.flatMap(MediaSourcePreference.init) ?? MediaSourcePreference.fallback

        switch preference {
        case .spotify:
            open(bundleIdentifier: "com.spotify.client")
        case .appleMusic:
            open(bundleIdentifier: "com.apple.Music")
        case .auto:
            let spotifyRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.spotify.client"
            }
            let musicRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.apple.Music"
            }
            open(bundleIdentifier: spotifyRunning || !musicRunning ? "com.spotify.client" : "com.apple.Music")
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
