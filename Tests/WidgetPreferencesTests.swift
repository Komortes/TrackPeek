import Foundation
import Testing
@testable import TrackPeek

@Suite("Widget preferences")
struct WidgetPreferencesTests {
    @Test("repeated migration does not clobber a value the user already changed")
    func repeatedMigrationDoesNotClobberExistingValue() {
        // Тест-хост запускает настоящий TrackPeekAppDelegate перед тестами, и тот
        // уже вызвал WidgetPreferences.registerDefaults() на .standard. Регистрация
        // UserDefaults общая на процесс (не на конкретный suite), поэтому
        // изолированный suite не может воспроизвести «ключ ещё не существует» —
        // отсюда здесь проверяется только идемпотентность повторного вызова.
        let suiteName = "widget-preferences-tests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        defaults.set(340.0, forKey: WidgetPreferences.widthKey)
        WidgetPreferences.migrateDefaultsIfNeeded(in: defaults)
        #expect(defaults.double(forKey: WidgetPreferences.widthKey) == 340.0)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("card size for the pill layout matches the compact notch size")
    func pillCardSizeMatchesCompactSize() {
        let size = WidgetPreferences.cardSize(layout: .pill, width: 320, heightAdjustment: 0)
        let expected = NotchPreferences.compactSize(width: 320, heightAdjustment: 0)
        #expect(size == expected)
    }
}
