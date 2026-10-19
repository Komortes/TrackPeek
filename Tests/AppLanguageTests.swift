import Foundation
import Testing
@testable import TrackPeek

@Suite("App language preferences")
struct AppLanguageTests {
    @Test("offers the system language and three supported languages in settings order")
    func supportedSelections() {
        #expect(AppLanguage.allCases == [.system, .english, .ukrainian, .russian])
        #expect(AppLanguage.allCases.map(\.id) == ["system", "en", "uk", "ru"])
        #expect(AppLanguage.preferenceKey == "AppleLanguages")
    }

    @Test("explicit languages use their native names")
    func nativeLanguageNames() {
        #expect(AppLanguage.english.title == "English")
        #expect(AppLanguage.ukrainian.title == "Українська")
        #expect(AppLanguage.russian.title == "Русский")
        #expect(AppLanguage.system.title == String(localized: "Follow macOS"))
    }

    @Test("an empty app domain follows macOS even when defaults register a language")
    func ignoresRegisteredLanguage() throws {
        let (defaults, domainName) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domainName) }
        defaults.register(defaults: ["AppleLanguages": ["ru"]])

        #expect(AppLanguage.selection(in: defaults, domainName: domainName) == .system)
        #expect(defaults.persistentDomain(forName: domainName)?["AppleLanguages"] == nil)
    }

    @Test("a language inherited from another suite does not count as an app override")
    func ignoresInheritedSuiteLanguage() throws {
        let (defaults, domainName) = try isolatedDefaults()
        let (inheritedDefaults, inheritedDomainName) = try isolatedDefaults()
        defer {
            defaults.removeSuite(named: inheritedDomainName)
            defaults.removePersistentDomain(forName: domainName)
            inheritedDefaults.removePersistentDomain(forName: inheritedDomainName)
        }
        inheritedDefaults.set(["uk"], forKey: "AppleLanguages")
        defaults.addSuite(named: inheritedDomainName)

        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["uk"])
        #expect(AppLanguage.selection(in: defaults, domainName: domainName) == .system)
    }

    @Test("each explicit language persists as an app override and round trips",
          arguments: [AppLanguage.english, .ukrainian, .russian])
    func savesExplicitLanguage(_ language: AppLanguage) throws {
        let (defaults, domainName) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domainName) }
        defaults.set("keep this preference", forKey: "unrelatedPreference")

        language.save(in: defaults)

        let savedDomain = defaults.persistentDomain(forName: domainName)
        #expect(savedDomain?["AppleLanguages"] as? [String] == [language.rawValue])
        #expect(savedDomain?["unrelatedPreference"] as? String == "keep this preference")
        #expect(AppLanguage.selection(in: defaults, domainName: domainName) == language)
    }

    @Test("following macOS removes only the app's language override")
    func removesOnlyLanguageOverride() throws {
        let (defaults, domainName) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domainName) }
        defaults.set(["ru"], forKey: "AppleLanguages")
        defaults.set("equalizer", forKey: "widgetTemplate")
        defaults.set(true, forKey: "widgetFreeMoveEnabled")
        defaults.register(defaults: ["AppleLanguages": ["uk"]])

        AppLanguage.system.save(in: defaults)

        let savedDomain = try #require(defaults.persistentDomain(forName: domainName))
        #expect(savedDomain["AppleLanguages"] == nil)
        #expect(savedDomain["widgetTemplate"] as? String == "equalizer")
        #expect(savedDomain["widgetFreeMoveEnabled"] as? Bool == true)
        #expect(savedDomain.count == 2)
        #expect(AppLanguage.selection(in: defaults, domainName: domainName) == .system)
    }

    @Test("regional app overrides resolve to their supported language", arguments: [
        ("en-US", AppLanguage.english),
        ("en_GB", AppLanguage.english),
        ("uk-UA", AppLanguage.ukrainian),
        ("uk_UA", AppLanguage.ukrainian),
        ("ru-RU", AppLanguage.russian),
        ("ru_RU", AppLanguage.russian),
    ])
    func regionalLanguageCodes(code: String, expected: AppLanguage) throws {
        let (defaults, domainName) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domainName) }
        defaults.set([code], forKey: "AppleLanguages")

        #expect(AppLanguage.selection(in: defaults, domainName: domainName) == expected)
        #expect(defaults.persistentDomain(forName: domainName)?["AppleLanguages"] as? [String] == [code])
    }

    @Test("the first app language determines the selected override")
    func firstPreferredLanguageWins() throws {
        let (defaults, domainName) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domainName) }
        defaults.set(["uk-UA", "en-US"], forKey: "AppleLanguages")

        #expect(AppLanguage.selection(in: defaults, domainName: domainName) == .ukrainian)
    }

    @Test("unsupported or malformed preferences follow macOS without changing stored values")
    func invalidValuesFallBackWithoutMutation() throws {
        let (defaults, domainName) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domainName) }
        let invalidValues: [Any] = [
            [String](), ["de"], ["es-MX"], [""], ["de", "uk"],
            "uk", 42, ["uk", 7], ["language": "uk"], [["uk"]],
        ]

        for value in invalidValues {
            defaults.set(value, forKey: "AppleLanguages")
            defaults.set("unchanged", forKey: "unrelatedPreference")
            let before = try #require(defaults.persistentDomain(forName: domainName))

            #expect(AppLanguage.selection(in: defaults, domainName: domainName) == .system)
            let after = try #require(defaults.persistentDomain(forName: domainName))
            #expect(NSDictionary(dictionary: before).isEqual(to: after))
        }
    }

    private func isolatedDefaults() throws -> (UserDefaults, String) {
        let domainName = "com.trackpeek.tests.app-language.\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: domainName)), domainName)
    }
}
