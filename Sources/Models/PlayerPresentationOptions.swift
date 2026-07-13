struct PlayerPresentationOptions: Equatable, Sendable {
    let showsAlbum: Bool
    let showsPlaybackStatus: Bool
    let showsArtworkShadow: Bool
}

enum PopoverBackgroundStyle: String, CaseIterable, Identifiable, Sendable {
    case systemMaterial
    case artworkBlur

    static let storageKey = "popoverBackgroundStyle"
    static let fallback: PopoverBackgroundStyle = .systemMaterial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemMaterial:
            "Системный материал"
        case .artworkBlur:
            "Размытая обложка"
        }
    }
}
