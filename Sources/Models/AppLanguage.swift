import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case ukrainian = "uk"
    case russian = "ru"

    static let preferenceKey = "AppleLanguages"
    static let selectionAtLaunch = selection()

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "Follow macOS")
        case .english: "English"
        case .ukrainian: "Українська"
        case .russian: "Русский"
        }
    }

    static func selection(
        in defaults: UserDefaults = .standard,
        domainName: String = Bundle.main.bundleIdentifier ?? "com.trackpeek.TrackPeek"
    ) -> AppLanguage {
        // The inherited AppleLanguages value represents macOS preferences,
        // so only an override saved in this app's domain is a selection.
        guard let languages = defaults.persistentDomain(forName: domainName)?[preferenceKey] as? [String],
              let code = languages.first?.split(whereSeparator: { $0 == "-" || $0 == "_" }).first,
              let language = AppLanguage(rawValue: code.lowercased()) else {
            return .system
        }
        return language
    }

    func save(in defaults: UserDefaults = .standard) {
        if self == .system {
            defaults.removeObject(forKey: Self.preferenceKey)
        } else {
            defaults.set([rawValue], forKey: Self.preferenceKey)
        }
    }
}
