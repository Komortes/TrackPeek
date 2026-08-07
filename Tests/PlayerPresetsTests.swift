import Foundation
import Testing
@testable import TrackPeek

@Suite("Player presets")
struct PlayerPresetsTests {
    private func makeDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("applying a behavior preset makes it the matching one")
    func behaviorApplyAndMatch() {
        let defaults = makeDefaults("presets-behavior")
        for preset in BehaviorPreset.allCases {
            preset.apply(in: defaults)
            #expect(preset.matches(defaults))
            for other in BehaviorPreset.allCases where other != preset {
                #expect(!other.matches(defaults))
            }
        }
        defaults.removePersistentDomain(forName: "presets-behavior")
    }

    @Test("a manual change turns the style preset into custom (no match)")
    func manualChangeBreaksStyleMatch() {
        let defaults = makeDefaults("presets-style")
        StylePreset.vivid.apply(in: defaults)
        #expect(StylePreset.vivid.matches(defaults))

        defaults.set(false, forKey: NotchPreferences.outlineShimmerKey)
        #expect(!StylePreset.vivid.matches(defaults))
        #expect(StylePreset.allCases.allSatisfy { !$0.matches(defaults) })
        defaults.removePersistentDomain(forName: "presets-style")
    }

    @Test("style presets configure both notch and widget keys")
    func stylePresetsCoverBothSurfaces() {
        let defaults = makeDefaults("presets-both")
        StylePreset.colored.apply(in: defaults)
        #expect(defaults.bool(forKey: NotchPreferences.coloredProgressKey))
        #expect(defaults.bool(forKey: WidgetPreferences.coloredProgressKey))
        #expect(
            defaults.string(forKey: NotchPreferences.pulseModeKey) == NotchPulseMode.off.rawValue
        )
        #expect(
            defaults.string(forKey: WidgetPreferences.pulseModeKey) == NotchPulseMode.off.rawValue
        )
        defaults.removePersistentDomain(forName: "presets-both")
    }
}
