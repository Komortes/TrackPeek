import Foundation

/// Снимок дисплея без зависимости от NSScreen — чтобы выбор экрана
/// оставался чистой тестируемой функцией.
struct DisplayDescriptor: Equatable, Sendable {
    var id: Int
    var hasNotch: Bool
    var isBuiltIn: Bool
    var persistentID: String? = nil
}

enum OverlaySurface: Sendable {
    case notch
    case floatingWidget
}

/// §20.1: automatic — чёлка только на дисплее с физическим вырезом
/// (без «виртуальной чёлки»), виджет предпочитает внешний монитор и
/// переезжает на встроенный при его отключении.
enum OverlayDisplayResolver {
    static func resolveIDs(
        surface: OverlaySurface,
        target: NotchDisplayTarget,
        displays: [DisplayDescriptor],
        selectedDisplayID: String? = nil
    ) -> [Int] {
        guard let first = displays.first else { return [] }

        if let selectedDisplayID {
            return [displays.first(where: { $0.persistentID == selectedDisplayID })?.id ?? first.id]
        }

        switch target {
        case .automatic:
            switch surface {
            case .notch:
                return displays.first(where: \.hasNotch).map { [$0.id] } ?? []
            case .floatingWidget:
                let preferred = displays.first { !$0.isBuiltIn } ?? first
                return [preferred.id]
            }
        case .mainDisplay:
            return [first.id]
        case .notchedDisplay:
            let notched = displays.first(where: \.hasNotch) ?? first
            return [notched.id]
        case .allDisplays:
            return displays.map(\.id)
        }
    }
}


/// Keeps the legacy policy values while allowing an explicit, persistent display.
enum DisplaySelection {
    private static let prefix = "display:"

    static func value(for persistentID: String) -> String { prefix + persistentID }

    static func persistentID(from value: String) -> String? {
        guard value.hasPrefix(prefix) else { return nil }
        let id = String(value.dropFirst(prefix.count))
        return id.isEmpty ? nil : id
    }
}
