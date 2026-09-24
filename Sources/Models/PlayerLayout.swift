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
            "Текст"
        case .compactHorizontal:
            "Compact"
        case .standard:
            "Standard"
        case .artworkVertical:
            "Artwork"
        }
    }

    var summary: String {
        switch self {
        case .lyrics:
            "Текущая строка и соседние; обычный текст можно читать целиком."
        case .compactHorizontal:
            "Быстрый горизонтальный контроллер."
        case .standard:
            "Сбалансированный вид с альбомом."
        case .artworkVertical:
            "Вертикальный вид с крупной обложкой."
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
