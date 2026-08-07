import Foundation

/// Позиция виджета: X левого края и Y верхнего края (top-anchored,
/// чтобы раскрытие пилюли росло вниз — та же семантика, что у старых
/// notchWidgetOriginX/notchWidgetOriginTopY).
struct WidgetPlacement: Equatable {
    var x: Double
    var topY: Double
}

/// Хранит позицию виджета по составному ключу «дисплей|раскладка»
/// (§20.2 анализа): смена раскладки или переезд на другой экран не
/// теряет позицию, запомненную для остальных комбинаций.
enum WidgetPlacementStore {
    static let storageKey = "widgetPlacements"

    private static func key(display: String, layout: NotchWidgetLayout) -> String {
        "\(display)|\(layout.rawValue)"
    }

    static func placement(
        display: String,
        layout: NotchWidgetLayout,
        in defaults: UserDefaults = .standard
    ) -> WidgetPlacement? {
        let all = defaults.dictionary(forKey: storageKey) as? [String: [String: Double]]
        guard
            let entry = all?[key(display: display, layout: layout)],
            let x = entry["x"],
            let topY = entry["topY"]
        else {
            return nil
        }
        return WidgetPlacement(x: x, topY: topY)
    }

    static func save(
        _ placement: WidgetPlacement,
        display: String,
        layout: NotchWidgetLayout,
        in defaults: UserDefaults = .standard
    ) {
        var all = defaults.dictionary(forKey: storageKey) as? [String: [String: Double]] ?? [:]
        all[key(display: display, layout: layout)] = ["x": placement.x, "topY": placement.topY]
        defaults.set(all, forKey: storageKey)
    }

    /// «Сбросить позицию» должен работать независимо от того, на каком
    /// дисплее сейчас живёт виджет, поэтому чистим записи раскладки
    /// на всех дисплеях сразу.
    static func removeAll(layout: NotchWidgetLayout, in defaults: UserDefaults = .standard) {
        guard var all = defaults.dictionary(forKey: storageKey) as? [String: [String: Double]] else {
            return
        }
        let suffix = "|\(layout.rawValue)"
        all = all.filter { !$0.key.hasSuffix(suffix) }
        defaults.set(all, forKey: storageKey)
    }

    /// Одноразовый перенос старой одиночной пары координат в словарь —
    /// под текущий дисплей и текущую раскладку, чтобы пользователь не
    /// потерял привычное положение виджета.
    static func migrateLegacyPlacementIfNeeded(
        display: String,
        layout: NotchWidgetLayout,
        in defaults: UserDefaults = .standard
    ) {
        guard
            placement(display: display, layout: layout, in: defaults) == nil,
            let x = defaults.object(forKey: WidgetPreferences.originXKey) as? Double,
            let topY = defaults.object(forKey: WidgetPreferences.originTopYKey) as? Double
        else {
            return
        }
        save(WidgetPlacement(x: x, topY: topY), display: display, layout: layout, in: defaults)
    }
}
