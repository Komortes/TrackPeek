import Foundation
import Testing
@testable import TrackPeek

@Suite("Widget placement store")
struct WidgetPlacementStoreTests {
    private func makeDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("stores independent positions per display and per layout")
    func storesIndependentPositions() {
        let defaults = makeDefaults("placement-independent")

        WidgetPlacementStore.save(
            WidgetPlacement(x: 10, topY: 900), display: "disp-A", layout: .pill, in: defaults
        )
        WidgetPlacementStore.save(
            WidgetPlacement(x: 500, topY: 400), display: "disp-A", layout: .miniBar, in: defaults
        )
        WidgetPlacementStore.save(
            WidgetPlacement(x: 77, topY: 200), display: "disp-B", layout: .pill, in: defaults
        )

        #expect(
            WidgetPlacementStore.placement(display: "disp-A", layout: .pill, in: defaults)
                == WidgetPlacement(x: 10, topY: 900)
        )
        #expect(
            WidgetPlacementStore.placement(display: "disp-A", layout: .miniBar, in: defaults)
                == WidgetPlacement(x: 500, topY: 400)
        )
        #expect(
            WidgetPlacementStore.placement(display: "disp-B", layout: .pill, in: defaults)
                == WidgetPlacement(x: 77, topY: 200)
        )
        #expect(
            WidgetPlacementStore.placement(display: "disp-B", layout: .miniBar, in: defaults) == nil
        )

        defaults.removePersistentDomain(forName: "placement-independent")
    }

    @Test("migrates the single legacy coordinate pair once")
    func migratesLegacyPairOnce() {
        let defaults = makeDefaults("placement-migration")
        defaults.set(88.0, forKey: WidgetPreferences.originXKey)
        defaults.set(1547.0, forKey: WidgetPreferences.originTopYKey)

        WidgetPlacementStore.migrateLegacyPlacementIfNeeded(
            display: "main", layout: .pill, in: defaults
        )

        #expect(
            WidgetPlacementStore.placement(display: "main", layout: .pill, in: defaults)
                == WidgetPlacement(x: 88, topY: 1547)
        )

        // Повторная миграция не перетирает уже сохранённое значение.
        WidgetPlacementStore.save(
            WidgetPlacement(x: 5, topY: 5), display: "main", layout: .pill, in: defaults
        )
        WidgetPlacementStore.migrateLegacyPlacementIfNeeded(
            display: "main", layout: .pill, in: defaults
        )
        #expect(
            WidgetPlacementStore.placement(display: "main", layout: .pill, in: defaults)
                == WidgetPlacement(x: 5, topY: 5)
        )

        defaults.removePersistentDomain(forName: "placement-migration")
    }

    @Test("removeAll clears a layout's placements on every display but keeps other layouts")
    func removeAllClearsLayoutAcrossDisplays() {
        let suiteName = "placement-remove-all"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        WidgetPlacementStore.save(
            WidgetPlacement(x: 1, topY: 2), display: "disp-A", layout: .pill, in: defaults
        )
        WidgetPlacementStore.save(
            WidgetPlacement(x: 3, topY: 4), display: "disp-B", layout: .pill, in: defaults
        )
        WidgetPlacementStore.save(
            WidgetPlacement(x: 5, topY: 6), display: "disp-A", layout: .miniBar, in: defaults
        )

        WidgetPlacementStore.removeAll(layout: .pill, in: defaults)

        #expect(WidgetPlacementStore.placement(display: "disp-A", layout: .pill, in: defaults) == nil)
        #expect(WidgetPlacementStore.placement(display: "disp-B", layout: .pill, in: defaults) == nil)
        #expect(
            WidgetPlacementStore.placement(display: "disp-A", layout: .miniBar, in: defaults)
                == WidgetPlacement(x: 5, topY: 6)
        )

        defaults.removePersistentDomain(forName: suiteName)
    }
}
