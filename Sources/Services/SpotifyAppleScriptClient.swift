import AppKit

@MainActor
protocol SpotifyPlaybackProviding {
    func fetchCurrentTrack() throws -> SpotifyTrack
    func playPause() throws
    func nextTrack() throws
    func previousTrack() throws
    func seek(to position: TimeInterval) throws
}

enum SpotifyPlaybackError: LocalizedError {
    case spotifyNotRunning
    case scriptFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .spotifyNotRunning:
            "Spotify не запущен."
        case let .scriptFailed(message):
            "Spotify недоступен: \(message)"
        case .invalidResponse:
            "Spotify вернул неожиданный ответ."
        }
    }
}

@MainActor
final class SpotifyAppleScriptClient: SpotifyPlaybackProviding {
    func fetchCurrentTrack() throws -> SpotifyTrack {
        guard isSpotifyRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        let descriptor = try execute(
            """
            tell application "Spotify"
                if player state is stopped then
                    return {"", "", "", "0", "0", "", player state as text}
                end if

                set activeTrack to current track
                set trackAlbum to album of activeTrack
                set trackArtworkURL to artwork url of activeTrack

                if trackAlbum is missing value then set trackAlbum to ""
                if trackArtworkURL is missing value then set trackArtworkURL to ""

                return {name of activeTrack, artist of activeTrack, trackAlbum as text, (duration of activeTrack) as text, (player position) as text, trackArtworkURL as text, player state as text}
            end tell
            """
        )

        let values = (1 ... 7).compactMap { descriptor.atIndex($0)?.stringValue }

        do {
            return try SpotifyTrackParser.parse(values)
        } catch {
            throw SpotifyPlaybackError.invalidResponse
        }
    }

    func playPause() throws {
        guard isSpotifyRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        _ = try execute("tell application \"Spotify\" to playpause")
    }

    func nextTrack() throws {
        guard isSpotifyRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        _ = try execute("tell application \"Spotify\" to next track")
    }

    func previousTrack() throws {
        guard isSpotifyRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        _ = try execute("tell application \"Spotify\" to previous track")
    }

    func seek(to position: TimeInterval) throws {
        guard isSpotifyRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        let seconds = max(position, 0)
        let value = String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            seconds
        )
        _ = try execute(
            "tell application \"Spotify\" to set player position to \(value)"
        )
    }

    private var isSpotifyRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.spotify.client"
        }
    }

    private func execute(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw SpotifyPlaybackError.scriptFailed("не удалось создать AppleScript")
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo["NSAppleScriptErrorMessage"] as? String
                ?? "неизвестная ошибка AppleScript"
            throw SpotifyPlaybackError.scriptFailed(message)
        }

        return result
    }
}
