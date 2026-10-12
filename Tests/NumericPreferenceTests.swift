import Testing
@testable import TrackPeek

@Suite("Invalid numeric preferences")
struct NumericPreferenceTests {
    @Test("notch dimensions, timing and effects fall back for nonfinite stored values",
          arguments: [Double.nan, .infinity, -.infinity])
    func notchFallbacks(_ value: Double) {
        #expect(NotchPreferences.clampedWidth(value) == NotchPreferences.widthFallback)
        #expect(NotchPreferences.clampedHeightAdjustment(value) == NotchPreferences.heightAdjustmentFallback)
        #expect(NotchPreferences.clampedHoverDelay(value) == NotchPreferences.hoverDelayFallback)
        #expect(NotchPreferences.clampedNotificationDuration(value) == NotchPreferences.notificationDurationFallback)
        #expect(NotchPreferences.clampedEqualizerSensitivity(value) == NotchPreferences.equalizerSensitivityFallback)
        #expect(NotchPreferences.clampedOutlineWidth(value) == NotchPreferences.outlineWidthFallback)
        #expect(NotchPreferences.clampedCornerRadius(value) == NotchPreferences.cornerRadiusFallback)
    }

    @Test("menu bar and artwork sizes stay renderable for nonfinite stored values",
          arguments: [Double.nan, .infinity, -.infinity])
    func playerFallbacks(_ value: Double) {
        #expect(MenuBarPreferences.clampedTitleWidth(value) == MenuBarPreferences.titleWidthFallback)
        #expect(MenuBarPreferences.clampedSpacing(value) == MenuBarPreferences.spacingFallback)
        #expect(ArtworkSizePreference.clamped(value) == ArtworkSizePreference.fallback)
    }
}
