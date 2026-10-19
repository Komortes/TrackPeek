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
            String(localized: "Menu Bar Only")
        case .notch:
            String(localized: "Notch")
        case .floatingWidget:
            String(localized: "Widget")
        }
    }

    var summary: String {
        switch self {
        case .off:
            String(localized: "Track information and controls in the menu bar, with no on-screen panel.")
        case .notch:
            String(localized: "A compact notch player that expands on hover.")
        case .floatingWidget:
            String(localized: "A pill or card at the edge of any display.")
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
