import Foundation

enum MenuBarPreferences {
    static let controlsEnabledKey = "menuBarControlsEnabled"
    static let showsTitleKey = "menuBarShowsTitle"
    static let showsEqualizerKey = "menuBarShowsEqualizer"
    static let titleWidthKey = "menuBarTitleWidth"
    static let spacingKey = "menuBarSpacing"

    static let controlsEnabledFallback = false
    static let showsTitleFallback = true
    static let showsEqualizerFallback = true
    static let titleWidthFallback = 140.0
    static let titleWidthRange = 60.0 ... 240.0
    static let titleWidthStep = 10.0
    static let spacingFallback = 6.0
    static let spacingRange = 2.0 ... 14.0
    static let spacingStep = 1.0

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            controlsEnabledKey: controlsEnabledFallback,
            showsTitleKey: showsTitleFallback,
            showsEqualizerKey: showsEqualizerFallback,
            titleWidthKey: titleWidthFallback,
            spacingKey: spacingFallback,
        ])
    }

    static func clampedTitleWidth(_ value: Double) -> Double {
        min(max(value, titleWidthRange.lowerBound), titleWidthRange.upperBound)
    }

    static func clampedSpacing(_ value: Double) -> Double {
        min(max(value, spacingRange.lowerBound), spacingRange.upperBound)
    }
}
