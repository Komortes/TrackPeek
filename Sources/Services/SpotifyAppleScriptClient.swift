import AppKit

@MainActor
protocol SpotifyPlaybackProviding {
    func fetchCurrentTrack() throws -> SpotifyTrack
    func playPause() throws
}

@MainActor
final class SpotifyAppleScriptClient: SpotifyPlaybackProviding {
    enum Error: LocalizedError {
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

    func fetchCurrentTrack() throws -> SpotifyTrack {
        guard isSpotifyRunning else {
            throw Error.spotifyNotRunning
        }

        let descriptor = try execute(
            """
            tell application "Spotify"
                return {name of current track, artist of current track, player state as text}
            end tell
            """
        )

        let values = (1 ... 3).compactMap { descriptor.atIndex($0)?.stringValue }

        do {
            return try SpotifyTrackParser.parse(values)
        } catch {
            throw Error.invalidResponse
        }
    }

    func playPause() throws {
        guard isSpotifyRunning else {
            throw Error.spotifyNotRunning
        }

        _ = try execute("tell application \"Spotify\" to playpause")
    }

    private var isSpotifyRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.spotify.client"
        }
    }

    private func execute(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw Error.scriptFailed("не удалось создать AppleScript")
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo["NSAppleScriptErrorMessage"] as? String
                ?? "неизвестная ошибка AppleScript"
            throw Error.scriptFailed(message)
        }

        return result
    }
}
