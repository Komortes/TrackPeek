import Foundation
enum MediaSourcePreference: String, CaseIterable, Identifiable, Sendable {
    case spotify
    case appleMusic
    case auto

    static let storageKey = "mediaSourcePreference"
    static let fallback: MediaSourcePreference = .spotify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spotify:
            "Spotify"
        case .appleMusic:
            "Apple Music"
        case .auto:
            String(localized: "Automatic")
        }
    }

    var summary: String {
        switch self {
        case .spotify:
            String(localized: "Always reads the track from Spotify.")
        case .appleMusic:
            String(localized: "Always reads the track from Music.app.")
        case .auto:
            String(localized: "Uses the player that is playing music, or the last active player if both are paused.")
        }
    }
}
