import Foundation
import Testing

@Suite("Localized app resources")
struct LocalizationTests {
    @Test("the app bundle advertises English, Ukrainian, and Russian")
    func supportedLanguagesAreBundled() {
        #expect(Set(Bundle.main.localizations).isSuperset(of: ["en", "uk", "ru"]))
    }

    @Test("General is translated in each language bundle", arguments: [
        ("en", "General"),
        ("uk", "Основні"),
        ("ru", "Основные"),
    ])
    func generalSidebarTitle(language: String, expected: String) throws {
        let bundle = try languageBundle(language)
        #expect(String(localized: "General", bundle: bundle, locale: Locale(identifier: language)) == expected)
    }

    @Test("translated interpolation preserves Unicode player names", arguments: [
        ("en", "Open"),
        ("uk", "Відкрити"),
        ("ru", "Открыть"),
    ])
    func openPlayerLabel(language: String, expectedVerb: String) throws {
        let bundle = try languageBundle(language)
        let name = "Björk — Київ 🎧"
        let label = String(localized: "Open \(name)", bundle: bundle, locale: Locale(identifier: language))
        #expect(label == "\(expectedVerb) \(name)")
    }

    @Test("volume percentages use the language's plural forms", arguments: [
        ("en", 1, "1 percent"),
        ("en", 2, "2 percent"),
        ("en", 5, "5 percent"),
        ("en", 21, "21 percent"),
        ("uk", 1, "1 відсоток"),
        ("uk", 2, "2 відсотки"),
        ("uk", 5, "5 відсотків"),
        ("uk", 21, "21 відсоток"),
        ("ru", 1, "1 процент"),
        ("ru", 2, "2 процента"),
        ("ru", 5, "5 процентов"),
        ("ru", 21, "21 процент"),
    ])
    func volumePercentage(language: String, count: Int, expected: String) throws {
        let bundle = try languageBundle(language)
        // A language bundle chooses the translation; the locale independently
        // chooses plural rules and must not come from the test runner's host.
        #expect(String(localized: "\(count) percent", bundle: bundle, locale: Locale(identifier: language)) == expected)
    }

    @Test("permission descriptions are present in every language's InfoPlist table",
          arguments: ["en", "uk", "ru"], ["NSAppleEventsUsageDescription", "NSAudioCaptureUsageDescription"])
    func localizedPermissionDescription(language: String, key: String) throws {
        let bundle = try languageBundle(language)
        let description = bundle.localizedString(forKey: key, value: nil, table: "InfoPlist")
        #expect(!description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(description != key, "Missing descriptions must not pass via the lookup-key fallback")
    }

    private func languageBundle(_ language: String) throws -> Bundle {
        let url = try #require(Bundle.main.url(forResource: language, withExtension: "lproj"))
        return try #require(Bundle(url: url))
    }
}
