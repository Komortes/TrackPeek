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

    @Test("window policy keys use stable raw strings and defaults")
    func windowPolicyKeysStable() {
        #expect(WidgetPreferences.alwaysOnTopKey == "widgetAlwaysOnTop")
        #expect(WidgetPreferences.allSpacesKey == "widgetAllSpaces")
        #expect(WidgetPreferences.hideInFullscreenKey == "widgetHideInFullscreen")
        #expect(WidgetPreferences.positionLockedKey == "widgetPositionLocked")

        let suiteName = "widget-window-policy-defaults"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        WidgetPreferences.registerDefaults(in: defaults)
        #expect(defaults.bool(forKey: WidgetPreferences.alwaysOnTopKey))
        #expect(defaults.bool(forKey: WidgetPreferences.allSpacesKey))
        #expect(!defaults.bool(forKey: WidgetPreferences.hideInFullscreenKey))
        #expect(!defaults.bool(forKey: WidgetPreferences.positionLockedKey))
        defaults.removePersistentDomain(forName: suiteName)
    }
}

extension WidgetPreferencesTests {
    @Test("Edge keeps its narrow fixed size independently of other templates")
    func edgeSize() {
        for width in [260.0, 320, 500] {
            #expect(WidgetPreferences.cardSize(layout: .edge, width: width, heightAdjustment: 40)
                    == CGSize(width: 72, height: 224))
        }
        #expect(NotchWidgetLayout.edge.family == .compact)
        #expect(NotchWidgetLayout.edge.isAlwaysExpanded)
    }

    @Test("Edge placement respects the visible frame on either display edge")
    func edgePlacement() {
        let bounds = CGRect(x: -1920, y: 25, width: 1860, height: 1000)
        let size = CGSize(width: 72, height: 224)
        let left = WidgetPreferences.edgeOrigin(in: bounds, size: size, onRight: false)
        let right = WidgetPreferences.edgeOrigin(in: bounds, size: size, onRight: true)
        #expect(left.x == bounds.minX + 12)
        #expect(right.x + size.width == bounds.maxX - 12)
        #expect(left.y + size.height / 2 == bounds.midY)
        #expect(left.y == right.y)
        #expect(bounds.contains(CGRect(origin: left, size: size)))
        #expect(bounds.contains(CGRect(origin: right, size: size)))
    }
}
