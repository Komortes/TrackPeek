import Foundation

enum DisplayMode: String, CaseIterable, Identifiable, Sendable {
    case menuBar
    case notch
    case floatingWidget

    static let fallback: DisplayMode = .menuBar
    static let storageKey = "displayMode"

    var id: String { rawValue }

    var isAvailable: Bool {
        true
    }

    var title: String {
        switch self {
        case .menuBar:
            "Menu Bar"
        case .notch:
            "Notch"
        case .floatingWidget:
            "Floating Widget"
        }
    }

    var summary: String {
        switch self {
        case .menuBar:
            "Трек, анимация звука и управление прямо в строке меню."
        case .notch:
            "Компактная чёлка, которая раскрывается при наведении."
        case .floatingWidget:
            "Пилюля у верхнего края любого экрана — как чёлка, но на мониторах без выреза."
        }
    }

    var symbolName: String {
        switch self {
        case .menuBar:
            "menubar.rectangle"
        case .notch:
            "macbook"
        case .floatingWidget:
            "rectangle.on.rectangle"
        }
    }
}
