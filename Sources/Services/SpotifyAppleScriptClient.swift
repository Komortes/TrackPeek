import AppKit

protocol SpotifyPlaybackProviding: Sendable {
    func fetchCurrentTrack() async throws -> SpotifyTrack
    func activeSource() async -> PlaybackSource
    func playPause() async throws
    func nextTrack() async throws
    func previousTrack() async throws
    func seek(to position: TimeInterval) async throws
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

actor SpotifyAppleScriptClient: SpotifyPlaybackProviding {
    func activeSource() -> PlaybackSource {
        .spotify
    }

    func fetchCurrentTrack() async throws -> SpotifyTrack {
        guard isSpotifyRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        let descriptor = try await execute(
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

    func playPause() async throws {
        guard isSpotifyRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        _ = try await execute("tell application \"Spotify\" to playpause")
    }

    func nextTrack() async throws {
        guard isSpotifyRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        _ = try await execute("tell application \"Spotify\" to next track")
    }

    func previousTrack() async throws {
        guard isSpotifyRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        _ = try await execute("tell application \"Spotify\" to previous track")
    }

    func seek(to position: TimeInterval) async throws {
        guard isSpotifyRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        let seconds = max(position, 0)
        let value = String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            seconds
        )
        _ = try await execute(
            "tell application \"Spotify\" to set player position to \(value)"
        )
    }

    private var isSpotifyRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.spotify.client"
        }
    }

    private func execute(_ source: String) async throws -> NSAppleEventDescriptor {
        do {
            return try await AppleScriptExecutor.execute(source)
        } catch AppleScriptExecutionError.timedOut {
            throw SpotifyPlaybackError.scriptFailed("Spotify не отвечает")
        } catch let AppleScriptExecutionError.scriptFailed(message) {
            throw SpotifyPlaybackError.scriptFailed(message)
        }
    }
}
