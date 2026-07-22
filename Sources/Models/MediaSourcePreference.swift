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
            "Автоматически"
        }
    }

    var summary: String {
        switch self {
        case .spotify:
            "Всегда читает трек из Spotify."
        case .appleMusic:
            "Всегда читает трек из Music.app."
        case .auto:
            "Использует запущенное приложение; Spotify в приоритете, если оба открыты."
        }
    }
}
