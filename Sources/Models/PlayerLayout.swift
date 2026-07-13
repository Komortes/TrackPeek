import Foundation

enum PlayerLayout: String, CaseIterable, Identifiable, Sendable {
    case compactHorizontal
    case standard
    case artworkVertical

    static let storageKey = "playerLayout"
    static let fallback: PlayerLayout = .standard

    var id: String { rawValue }

    var title: String {
        switch self {
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
        case .compactHorizontal:
            "Быстрый горизонтальный контроллер."
        case .standard:
            "Сбалансированный вид с альбомом."
        case .artworkVertical:
            "Вертикальный вид с крупной обложкой."
        }
    }

    var popoverSize: CGSize {
        switch self {
        case .compactHorizontal:
            CGSize(width: 390, height: 144)
        case .standard:
            CGSize(width: 350, height: 286)
        case .artworkVertical:
            CGSize(width: 310, height: 438)
        }
    }
}
