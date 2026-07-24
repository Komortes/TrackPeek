import AppKit

actor MusicAppleScriptClient: SpotifyPlaybackProviding {
    private static let bundleIdentifier = "com.apple.Music"

    private var cachedArtworkIdentity: String?
    private var cachedArtworkURL: URL?

    func activeSource() -> PlaybackSource {
        .appleMusic
    }

    func fetchCurrentTrack() async throws -> SpotifyTrack {
        guard isMusicRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        let descriptor = try await execute(
            """
            tell application "Music"
                if player state is stopped then
                    return {"", "", "", "0", "0", player state as text}
                end if

                set activeTrack to current track
                set trackAlbum to album of activeTrack
                if trackAlbum is missing value then set trackAlbum to ""

                return {name of activeTrack, artist of activeTrack, trackAlbum as text, (duration of activeTrack) as text, (player position) as text, player state as text}
            end tell
            """
        )

        let values = (1 ... 6).compactMap { descriptor.atIndex($0)?.stringValue }

        guard
            values.count >= 6,
            let duration = parseNumber(values[3]),
            let position = parseNumber(values[4])
        else {
            throw SpotifyPlaybackError.invalidResponse
        }

        let title = values[0]
        let artist = values[1]
        let album = values[2].isEmpty ? nil : values[2]
        let isPlaying = values[5].caseInsensitiveCompare("playing") == .orderedSame

        var artworkURL: URL?
        if !title.isEmpty {
            artworkURL = await resolvedArtworkURL(
                trackIdentity: "\(title)\u{1F}\(artist)\u{1F}\(album ?? "")"
            )
        }

        return SpotifyTrack(
            title: title,
            artist: artist,
            album: album,
            duration: max(duration, 0),
            position: max(position, 0),
            artworkURL: artworkURL,
            isPlaying: isPlaying
        )
    }

    func playPause() async throws {
        guard isMusicRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        _ = try await execute("tell application \"Music\" to playpause")
    }

    func nextTrack() async throws {
        guard isMusicRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        _ = try await execute("tell application \"Music\" to next track")
    }

    func previousTrack() async throws {
        guard isMusicRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        _ = try await execute("tell application \"Music\" to previous track")
    }

    func seek(to position: TimeInterval) async throws {
        guard isMusicRunning else {
            throw SpotifyPlaybackError.spotifyNotRunning
        }

        let seconds = max(position, 0)
        let value = String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            seconds
        )
        _ = try await execute(
            "tell application \"Music\" to set player position to \(value)"
        )
    }

    private var isMusicRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == Self.bundleIdentifier
        }
    }

    /// Music.app has no artwork URL like Spotify — artwork is embedded binary
    /// data, so it is written once per track to a stable temp file and
    /// reused via a `file://` URL through the same artwork pipeline.
    private func resolvedArtworkURL(trackIdentity: String) async -> URL? {
        if cachedArtworkIdentity == trackIdentity {
            return cachedArtworkURL
        }

        guard
            let descriptor = try? await execute(
                "tell application \"Music\" to get data of artwork 1 of current track"
            ),
            let data = descriptor.data as Data?,
            !data.isEmpty
        else {
            cachedArtworkIdentity = trackIdentity
            cachedArtworkURL = nil
            return nil
        }

        let filename = "trackpeek-music-artwork-\(abs(trackIdentity.hashValue)).jpg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }

        if let previous = cachedArtworkURL, previous != url {
            try? FileManager.default.removeItem(at: previous)
        }

        cachedArtworkIdentity = trackIdentity
        cachedArtworkURL = url
        return url
    }

    private func parseNumber(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private func execute(_ source: String) async throws -> NSAppleEventDescriptor {
        do {
            return try await AppleScriptExecutor.execute(source)
        } catch AppleScriptExecutionError.timedOut {
            throw SpotifyPlaybackError.scriptFailed("Music не отвечает")
        } catch let AppleScriptExecutionError.scriptFailed(message) {
            throw SpotifyPlaybackError.scriptFailed(message)
        }
    }
}
