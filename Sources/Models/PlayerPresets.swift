import Foundation

/// Значение одного ключа в составе пресета.
enum PresetValue: Equatable {
    case bool(Bool)
    case double(Double)
    case string(String)

    func write(to defaults: UserDefaults, key: String) {
        switch self {
        case let .bool(value): defaults.set(value, forKey: key)
        case let .double(value): defaults.set(value, forKey: key)
        case let .string(value): defaults.set(value, forKey: key)
        }
    }

    func matches(_ defaults: UserDefaults, key: String) -> Bool {
        switch self {
        case let .bool(value): defaults.bool(forKey: key) == value
        case let .double(value): abs(defaults.double(forKey: key) - value) < 0.001
        case let .string(value): defaults.string(forKey: key) == value
        }
    }
}

protocol PresetDefinition {
    var values: [String: PresetValue] { get }
}

extension PresetDefinition {
    /// Apply-and-forget (§21.1): пресет пишет значения один раз; «текущим»
    /// он считается, только пока все его значения совпадают с defaults —
    /// любое ручное изменение делает состояние «Пользовательским».
    func apply(in defaults: UserDefaults) {
        for (key, value) in values {
            value.write(to: defaults, key: key)
        }
    }

    func matches(_ defaults: UserDefaults) -> Bool {
        values.allSatisfy { $0.value.matches(defaults, key: $0.key) }
    }
}

/// §12.1: скорость реакции чёлки (hover, уведомления о треке).
enum BehaviorPreset: String, CaseIterable, Identifiable, PresetDefinition {
    case calm
    case balanced
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "Спокойное"
        case .balanced: "Сбалансированное"
        case .fast: "Быстрое"
        }
    }

    var values: [String: PresetValue] {
        switch self {
        case .calm:
            [
                NotchPreferences.hoverDelayKey: .double(0.5),
                NotchPreferences.notificationsEnabledKey: .bool(false),
                NotchPreferences.notificationDurationKey: .double(3.0),
            ]
        case .balanced:
            [
                NotchPreferences.hoverDelayKey: .double(0.25),
                NotchPreferences.notificationsEnabledKey: .bool(true),
                NotchPreferences.notificationDurationKey: .double(3.0),
            ]
        case .fast:
            [
                NotchPreferences.hoverDelayKey: .double(0.15),
                NotchPreferences.notificationsEnabledKey: .bool(true),
                NotchPreferences.notificationDurationKey: .double(1.5),
            ]
        }
    }
}

/// §12.2: визуальный характер. Один пресет настраивает ОБЕ поверхности
/// (чёлку и виджет) — раздельные наборы отложены как P2 (§21.1).
enum StylePreset: String, CaseIterable, Identifiable, PresetDefinition {
    case minimal
    case colored
    case vivid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: "Минимальный"
        case .colored: "Цветной"
        case .vivid: "Живой"
        }
    }

    var values: [String: PresetValue] {
        var result: [String: PresetValue] = [:]
        let pairs: [(notch: String, widget: String)] = [
            (NotchPreferences.outlineShimmerKey, WidgetPreferences.outlineShimmerKey),
            (NotchPreferences.coloredProgressKey, WidgetPreferences.coloredProgressKey),
            (NotchPreferences.coloredWaveformKey, WidgetPreferences.coloredWaveformKey),
            (NotchPreferences.colorSourceKey, WidgetPreferences.colorSourceKey),
            (NotchPreferences.pulseModeKey, WidgetPreferences.pulseModeKey),
        ]
        let shimmer: Bool
        let colored: Bool
        let colorSource: NotchColorSource
        let pulse: NotchPulseMode

        switch self {
        case .minimal:
            (shimmer, colored, colorSource, pulse) = (false, false, .systemAccent, .off)
        case .colored:
            (shimmer, colored, colorSource, pulse) = (false, true, .artwork, .off)
        case .vivid:
            (shimmer, colored, colorSource, pulse) = (true, true, .artwork, .glow)
        }

        let presetValues: [PresetValue] = [
            .bool(shimmer), .bool(colored), .bool(colored),
            .string(colorSource.rawValue), .string(pulse.rawValue),
        ]
        for (pair, value) in zip(pairs, presetValues) {
            result[pair.notch] = value
            result[pair.widget] = value
        }
        return result
    }
}
