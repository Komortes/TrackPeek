enum PlaybackAvailability: Equatable, Sendable {
    case loading
    case ready
    case nothingPlaying
    case spotifyNotRunning
    case unavailable
}
