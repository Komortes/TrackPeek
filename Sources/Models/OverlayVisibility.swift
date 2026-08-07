import Foundation

/// Когда экранная панель (чёлка или виджет) вообще видна. Общая политика
/// для обеих поверхностей — §20.3 анализа.
enum OverlayVisibilityPolicy: String, CaseIterable, Identifiable, Sendable {
    case always
    case whileSourceRunning
    case whilePlaying

    static let fallback: OverlayVisibilityPolicy = .always
    static let storageKey = "overlayVisibilityPolicy"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .always:
            "Всегда"
        case .whileSourceRunning:
            "Пока плеер запущен"
        case .whilePlaying:
            "Только при воспроизведении"
        }
    }
}

/// Единственная точка истины «видна ли панель сейчас». Все контроллеры
/// зовут её, а не комбинируют условия самостоятельно.
enum OverlayVisibility {
    /// Ключ «Временно скрыть»: сбрасывается при каждом запуске приложения,
    /// поэтому это состояние, а не ещё один режим (§3.2 анализа).
    static let temporarilyHiddenKey = "overlayTemporarilyHidden"

    static func isVisible(
        mode: OverlayMode,
        temporarilyHidden: Bool,
        policy: OverlayVisibilityPolicy,
        availability: PlaybackAvailability,
        isPlaying: Bool
    ) -> Bool {
        guard mode != .off, !temporarilyHidden else { return false }

        switch policy {
        case .always:
            return true
        case .whileSourceRunning:
            // .unavailable — сбой запроса, а не отсутствие плеера:
            // при ошибке панель остаётся видимой и показывает состояние.
            return availability != .spotifyNotRunning
        case .whilePlaying:
            return isPlaying
        }
    }
}
