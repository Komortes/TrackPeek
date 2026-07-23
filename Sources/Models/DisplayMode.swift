import Foundation

/// Экранный плеер поверх рабочего стола. Menu Bar существует всегда и не
/// является режимом: OverlayMode определяет только видимость NSPanel.
enum OverlayMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case notch
    case floatingWidget

    static let fallback: OverlayMode = .off
    static let storageKey = "overlayMode"

    /// Ключ старой модели с тремя взаимоисключающими режимами.
    static let legacyStorageKey = "displayMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            "Только Menu Bar"
        case .notch:
            "Чёлка"
        case .floatingWidget:
            "Виджет"
        }
    }

    var summary: String {
        switch self {
        case .off:
            "Без экранной панели: трек и управление в строке меню."
        case .notch:
            "Компактная чёлка, которая раскрывается при наведении."
        case .floatingWidget:
            "Пилюля или карточка у края любого экрана."
        }
    }

    var symbolName: String {
        switch self {
        case .off:
            "menubar.rectangle"
        case .notch:
            "macbook"
        case .floatingWidget:
            "rectangle.on.rectangle"
        }
    }

    /// Переносит сохранённый выбор из старой модели `displayMode`.
    static func migrateIfNeeded(in defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: storageKey) == nil,
              let legacy = defaults.string(forKey: legacyStorageKey) else {
            return
        }

        let migrated: OverlayMode = switch legacy {
        case "notch": .notch
        case "floatingWidget": .floatingWidget
        default: .off
        }
        defaults.set(migrated.rawValue, forKey: storageKey)
    }
}
