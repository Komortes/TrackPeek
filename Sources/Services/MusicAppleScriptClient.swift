import AppKit

actor MusicAppleScriptClient: SpotifyPlaybackProviding {
    private static let bundleIdentifier = "com.apple.Music"

    private var cachedArtworkIdentity: String?
    private var cachedArtworkURL: URL?
    private var ownedArtworkURL: URL?
    private var artworkRetryAfter: TimeInterval?
    private var artworkGeneration: UInt64 = 0
    private let artworkLoader: (@Sendable () async throws -> Data?)?
    private let artworkDirectory: URL
    private let artworkTime: @Sendable () -> TimeInterval
    private let removeArtworkFile: @Sendable (URL) throws -> Void

    init(artworkLoader: (@Sendable () async throws -> Data?)? = nil,
         artworkDirectory: URL = FileManager.default.temporaryDirectory,
         artworkTime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         removeArtworkFile: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
        self.artworkLoader = artworkLoader
        self.artworkDirectory = artworkDirectory
        self.artworkTime = artworkTime
        self.removeArtworkFile = removeArtworkFile
    }

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
                    return {"", "", "", "0", "0", player state as text, "", "", ""}
                end if

                set activeTrack to current track
                set trackAlbum to album of activeTrack
                if trackAlbum is missing value then set trackAlbum to ""

                return {name of activeTrack, artist of activeTrack, trackAlbum as text, (duration of activeTrack) as text, (player position) as text, player state as text, (shuffle enabled) as text, song repeat as text, (sound volume) as text}
            end tell
            """
        )

        let values = (1 ... 9).compactMap { descriptor.atIndex($0)?.stringValue }

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
            artworkURL = try await resolvedArtworkURL(
                trackIdentity: "\(title)\u{1F}\(artist)\u{1F}\(album ?? "")"
            )
        }

        var track = SpotifyTrack(
            title: title,
            artist: artist,
            album: album,
            duration: max(duration, 0),
            position: max(position, 0),
            artworkURL: artworkURL,
            isPlaying: isPlaying
        )
        if values.count >= 9 {
            track.secondary = PlaybackSecondaryState(
                isShuffling: Bool(values[6]),
                repeatMode: RepeatMode(rawValue: values[7]),
                volume: Int(values[8])
            )
        }
        return track
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

    func setShuffle(_ enabled: Bool) async throws {
        guard isMusicRunning else { throw SpotifyPlaybackError.spotifyNotRunning }
        _ = try await execute("tell application \"Music\" to set shuffle enabled to \(enabled)")
    }

    func setRepeat(_ mode: RepeatMode) async throws {
        guard isMusicRunning else { throw SpotifyPlaybackError.spotifyNotRunning }
        _ = try await execute("tell application \"Music\" to set song repeat to \(mode.rawValue)")
    }

    func setVolume(_ volume: Int) async throws {
        guard isMusicRunning else { throw SpotifyPlaybackError.spotifyNotRunning }
        let clamped = min(max(volume, 0), 100)
        _ = try await execute("tell application \"Music\" to set sound volume to \(clamped)")
    }

    private var isMusicRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == Self.bundleIdentifier
        }
    }

    /// Music.app has no artwork URL like Spotify — artwork is embedded binary
    /// data, so it is written once per track to a stable temp file and
    /// reused via a `file://` URL through the same artwork pipeline.
    func resolvedArtworkURL(trackIdentity: String) async throws -> URL? {
        try Task.checkCancellation()
        artworkGeneration &+= 1
        let generation = artworkGeneration
        if cachedArtworkIdentity == trackIdentity {
            if let artworkRetryAfter {
                if artworkTime() < artworkRetryAfter { return nil }
            } else {
                return cachedArtworkURL
            }
        }

        let result: Result<Data?, Error>
        do {
            if let artworkLoader {
                result = .success(try await artworkLoader())
            } else {
                result = .success(try await loadCurrentArtwork())
            }
        } catch {
            result = .failure(error)
        }
        try Task.checkCancellation()
        guard generation == artworkGeneration else { throw CancellationError() }
        if case .failure(let error) = result, error is CancellationError {
            throw CancellationError()
        }

        // Cancellation and stale completions leave the previous cache intact.
        // From here the transition is synchronous: retire the sole owned file
        // before writing a replacement, retaining its owner if removal fails.
        cachedArtworkIdentity = trackIdentity
        cachedArtworkURL = nil
        do {
            try retireArtworkFile()
            guard let data = try result.get() else {
                artworkRetryAfter = nil
                return nil
            }
            guard !data.isEmpty else { throw SpotifyPlaybackError.invalidResponse }
            let url = artworkDirectory.appendingPathComponent("trackpeek-music-artwork-\(UUID().uuidString).jpg")
            try data.write(to: url, options: .atomic)
            ownedArtworkURL = url
            cachedArtworkURL = url
            artworkRetryAfter = nil
            return url
        } catch {
            // Later coordinator polls may retry; no separate timer or retry loop.
            artworkRetryAfter = artworkTime() + 5
            return nil
        }
    }

    private func retireArtworkFile() throws {
        guard let url = ownedArtworkURL else { return }
        do {
            try removeArtworkFile(url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            // A temporary file can be removed externally; it no longer needs an owner.
        }
        ownedArtworkURL = nil
    }

    private func loadCurrentArtwork() async throws -> Data? {
        let descriptor = try await execute(
            """
            tell application "Music"
                if (count of artworks of current track) is 0 then return {false}
                return {true, data of artwork 1 of current track}
            end tell
            """
        )
        return try Self.artworkData(from: descriptor)
    }

    static func artworkData(from descriptor: NSAppleEventDescriptor) throws -> Data? {
        guard descriptor.descriptorType == typeAEList, let present = descriptor.atIndex(1),
              [typeBoolean, typeTrue, typeFalse].contains(present.descriptorType) else {
            throw SpotifyPlaybackError.invalidResponse
        }
        if !present.booleanValue {
            guard descriptor.numberOfItems == 1 else { throw SpotifyPlaybackError.invalidResponse }
            return nil
        }
        guard descriptor.numberOfItems == 2, let data = descriptor.atIndex(2)?.data, !data.isEmpty else {
            throw SpotifyPlaybackError.invalidResponse
        }
        return data
    }

    private func parseNumber(_ value: String) -> Double? {
        guard let number = Double(value.replacingOccurrences(of: ",", with: ".")),
              number.isFinite else { return nil }
        return number
    }

    private func execute(_ source: String) async throws -> NSAppleEventDescriptor {
        do {
            return try await AppleScriptExecutor.execute(source, targetBundleIdentifier: Self.bundleIdentifier)
        } catch AppleScriptExecutionError.automationDenied {
            throw SpotifyPlaybackError.automationDenied
        } catch AppleScriptExecutionError.timedOut {
            throw SpotifyPlaybackError.scriptFailed(String(localized: "Music is not responding"))
        } catch let AppleScriptExecutionError.scriptFailed(message) {
            if message.contains("-1743") || message.localizedCaseInsensitiveContains("not authorized")
                || message.localizedCaseInsensitiveContains("не разрешено") {
                throw SpotifyPlaybackError.automationDenied
            }
            throw SpotifyPlaybackError.scriptFailed(message)
        }
    }
}
