struct PlayerPresentationOptions: Equatable, Sendable {
    let showsAlbum: Bool
    let showsPlaybackStatus: Bool
    let showsArtworkShadow: Bool
}

enum PlayerMotion {
    static let playbackDuration = 0.24
    static let controlDuration = 0.14
    static let equalizerDuration = 0.28
    static let spectrumFrameDuration = 0.05
}

enum ArtworkSizePreference {
    static let storageKey = "artworkSize"
    static let fallback = 250.0
    static let range = 210.0 ... 274.0
    static let step = 2.0

    static func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
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
