import Foundation

enum PlayerLayout: String, CaseIterable, Identifiable, Sendable {
    case compactHorizontal
    case standard
    case artworkVertical
    case lyrics

    static let storageKey = "playerLayout"
    static let fallback: PlayerLayout = .standard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lyrics:
            String(localized: "Lyrics")
        case .compactHorizontal:
            String(localized: "Compact")
        case .standard:
            String(localized: "Standard")
        case .artworkVertical:
            String(localized: "Artwork")
        }
    }

    var summary: String {
        switch self {
        case .lyrics:
            String(localized: "Full song lyrics. Click a line to seek to it.")
        case .compactHorizontal:
            String(localized: "A compact horizontal controller.")
        case .standard:
            String(localized: "A balanced layout with album information.")
        case .artworkVertical:
            String(localized: "A vertical layout with large artwork.")
        }
    }

    var popoverSize: CGSize {
        popoverSize(artworkSize: ArtworkSizePreference.fallback)
    }

    func popoverSize(artworkSize: Double) -> CGSize {
        switch self {
        case .lyrics:
            CGSize(width: 380, height: 470)
        case .compactHorizontal:
            CGSize(width: 390, height: 144)
        case .standard:
            CGSize(width: 350, height: 286)
        case .artworkVertical:
            CGSize(
                width: 310,
                height: ArtworkSizePreference.clamped(artworkSize) + 225
            )
        }
    }
}
