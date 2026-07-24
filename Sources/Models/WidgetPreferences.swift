import CoreGraphics
import Foundation

/// Ключи, размеры и дефолты floating-виджета. Отделены от `NotchPreferences`,
/// чтобы переключение между чёлкой и виджетом не делило один набор настроек —
/// см. §9.3/§10.6 в docs/superpowers/trackpeek-modes-product-analysis.md.
enum WidgetPreferences {
    static let positionKey = "notchWidgetPosition"
    static let layoutKey = "notchWidgetLayout"
    static let freeMoveKey = "notchWidgetFreeMove"
    static let originXKey = "notchWidgetOriginX"
    static let originTopYKey = "notchWidgetOriginTopY"
    static let outlineShimmerKey = "widgetOutlineShimmer"
    static let outlineWidthKey = "widgetOutlineWidth"
    static let pulseModeKey = "widgetPulseMode"
    static let glassBackgroundKey = "widgetGlassBackground"
    static let widthKey = "widgetWidth"
    static let displayTargetKey = "widgetDisplayTarget"
    static let coloredProgressKey = "widgetColoredProgress"
    static let coloredWaveformKey = "widgetColoredWaveform"
    static let colorSourceKey = "widgetColorSource"
    static let equalizerSensitivityKey = "widgetEqualizerSensitivity"
    static let lyricsEnabledKey = "widgetLyricsEnabled"

    /// Отступы floating-виджета от краёв экрана.
    static let topInset = 8.0
    static let edgeMargin = 12.0

    /// Одноразовый перенос: раньше виджет использовал настройки чёлки —
    /// существующие пользователи сохраняют текущий вид.
    static func migrateDefaultsIfNeeded(in defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: widthKey) == nil else { return }

        let pairs: [(source: String, destination: String)] = [
            (NotchPreferences.widthKey, widthKey),
            (NotchPreferences.displayTargetKey, displayTargetKey),
            (NotchPreferences.coloredProgressKey, coloredProgressKey),
            (NotchPreferences.coloredWaveformKey, coloredWaveformKey),
            (NotchPreferences.colorSourceKey, colorSourceKey),
            (NotchPreferences.equalizerSensitivityKey, equalizerSensitivityKey),
            (NotchPreferences.lyricsEnabledKey, lyricsEnabledKey),
        ]
        for pair in pairs {
            if let value = defaults.object(forKey: pair.source) {
                defaults.set(value, forKey: pair.destination)
            }
        }
    }

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            positionKey: NotchWidgetPosition.fallback.rawValue,
            layoutKey: NotchWidgetLayout.fallback.rawValue,
            freeMoveKey: false,
            outlineShimmerKey: NotchPreferences.outlineShimmerFallback,
            outlineWidthKey: NotchPreferences.outlineWidthFallback,
            pulseModeKey: NotchPulseMode.fallback.rawValue,
            glassBackgroundKey: false,
            widthKey: NotchPreferences.widthFallback,
            displayTargetKey: NotchDisplayTarget.mainDisplay.rawValue,
            coloredProgressKey: NotchPreferences.coloredProgressFallback,
            coloredWaveformKey: NotchPreferences.coloredWaveformFallback,
            colorSourceKey: NotchColorSource.fallback.rawValue,
            equalizerSensitivityKey: NotchPreferences.equalizerSensitivityFallback,
            lyricsEnabledKey: NotchPreferences.lyricsEnabledFallback,
        ])
    }

    /// Постоянный размер карточных раскладок floating-виджета.
    static func cardSize(
        layout: NotchWidgetLayout,
        width: Double,
        heightAdjustment: Double
    ) -> CGSize {
        switch layout {
        case .pill:
            NotchPreferences.compactSize(width: width, heightAdjustment: heightAdjustment)
        case .miniBar:
            CGSize(width: max(NotchPreferences.clampedWidth(width) + 20, 340), height: 44)
        case .cardHorizontal:
            NotchPreferences.expandedSize(width: width, heightAdjustment: heightAdjustment)
        case .cardVertical:
            CGSize(width: max(NotchPreferences.clampedWidth(width) * 0.72, 250), height: 296)
        case .artworkSquare:
            CGSize(
                width: max(NotchPreferences.clampedWidth(width) * 0.58, 190),
                height: max(NotchPreferences.clampedWidth(width) * 0.58, 190)
            )
        case .lyricsCard:
            CGSize(width: max(NotchPreferences.clampedWidth(width) + 60, 380), height: 78)
        case .karaokeCard:
            CGSize(width: max(NotchPreferences.clampedWidth(width) + 80, 400), height: 188)
        case .equalizerCard:
            CGSize(width: max(NotchPreferences.clampedWidth(width) * 0.82, 268), height: 132)
        }
    }
}
