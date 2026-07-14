import AppKit

protocol SpotifyPlaybackProviding: Sendable {
    func fetchCurrentTrack() async throws -> SpotifyTrack
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
    private static let executionTimeout: Duration = .seconds(5)

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

    /// Runs the blocking `NSAppleScript` call off the actor's executor so a
    /// hung/unresponsive Spotify can't stall every other queued command;
    /// a sibling task races it with a timeout and wins if Spotify never replies.
    private func execute(_ source: String) async throws -> NSAppleEventDescriptor {
        let scriptTask = Task.detached(priority: .userInitiated) { () -> UncheckedSendableBox<NSAppleEventDescriptor> in
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

            return UncheckedSendableBox(value: result)
        }

        return try await withThrowingTaskGroup(of: UncheckedSendableBox<NSAppleEventDescriptor>.self) { group in
            group.addTask { try await scriptTask.value }
            group.addTask {
                try await Task.sleep(for: Self.executionTimeout)
                throw SpotifyPlaybackError.scriptFailed("Spotify не отвечает")
            }

            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw SpotifyPlaybackError.invalidResponse
            }
            return result.value
        }
    }
}

/// Lets a non-Sendable AppleScript result cross a Task boundary; safe because
/// the value is produced once and consumed once, never shared concurrently.
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
}
