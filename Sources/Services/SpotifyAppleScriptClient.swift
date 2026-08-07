import AppKit

protocol SpotifyPlaybackProviding: Sendable {
    func fetchCurrentTrack() async throws -> SpotifyTrack
    func activeSource() async -> PlaybackSource
    func playPause() async throws
    func nextTrack() async throws
    func previousTrack() async throws
    func seek(to position: TimeInterval) async throws
    func setShuffle(_ enabled: Bool) async throws
    func setRepeat(_ mode: RepeatMode) async throws
    func setVolume(_ volume: Int) async throws
}

enum SpotifyPlaybackError: LocalizedError {
    case spotifyNotRunning
    case scriptFailed(String)
    case invalidResponse
    case automationDenied

    var errorDescription: String? {
        switch self {
        case .spotifyNotRunning:
            "Spotify не запущен."
        case let .scriptFailed(message):
            "Spotify недоступен: \(message)"
        case .invalidResponse:
            "Spotify вернул неожиданный ответ."
        case .automationDenied:
            "Нет разрешения управлять плеером. Разрешите Automation в Настройках конфиденциальности."
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
                    return {"", "", "", "0", "0", "", player state as text, "", "", ""}
                end if

                set activeTrack to current track
                set trackAlbum to album of activeTrack
                set trackArtworkURL to artwork url of activeTrack

                if trackAlbum is missing value then set trackAlbum to ""
                if trackArtworkURL is missing value then set trackArtworkURL to ""

                return {name of activeTrack, artist of activeTrack, trackAlbum as text, (duration of activeTrack) as text, (player position) as text, trackArtworkURL as text, player state as text, shuffling as text, repeating as text, (sound volume) as text}
            end tell
            """
        )

        let values = (1 ... 10).compactMap { descriptor.atIndex($0)?.stringValue }

        var normalized = values
        if normalized.count >= 10 {
            // Spotify: repeating — boolean; приводим к словарю RepeatMode.
            normalized[8] = normalized[8] == "true" ? "all" : "off"
        }

        do {
            return try SpotifyTrackParser.parse(normalized)
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

    func setShuffle(_ enabled: Bool) async throws {
        guard isSpotifyRunning else { throw SpotifyPlaybackError.spotifyNotRunning }
        _ = try await execute("tell application \"Spotify\" to set shuffling to \(enabled)")
    }

    func setRepeat(_ mode: RepeatMode) async throws {
        guard isSpotifyRunning else { throw SpotifyPlaybackError.spotifyNotRunning }
        // Spotify AppleScript знает только boolean repeating: one → all.
        let enabled = mode != .off
        _ = try await execute("tell application \"Spotify\" to set repeating to \(enabled)")
    }

    func setVolume(_ volume: Int) async throws {
        guard isSpotifyRunning else { throw SpotifyPlaybackError.spotifyNotRunning }
        let clamped = min(max(volume, 0), 100)
        _ = try await execute("tell application \"Spotify\" to set sound volume to \(clamped)")
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
            if message.contains("-1743") || message.localizedCaseInsensitiveContains("not authorized")
                || message.localizedCaseInsensitiveContains("не разрешено") {
                throw SpotifyPlaybackError.automationDenied
            }
            throw SpotifyPlaybackError.scriptFailed(message)
        }
    }
}
