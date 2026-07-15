import CoreGraphics
import Foundation

enum NotchDisplayTarget: String, CaseIterable, Identifiable, Sendable {
    case mainDisplay
    case notchedDisplay
    case allDisplays

    static let fallback: NotchDisplayTarget = .notchedDisplay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mainDisplay:
            "Основной"
        case .notchedDisplay:
            "С чёлкой"
        case .allDisplays:
            "Все экраны"
        }
    }

    var symbolName: String {
        switch self {
        case .mainDisplay:
            "display"
        case .notchedDisplay:
            "laptopcomputer"
        case .allDisplays:
            "rectangle.on.rectangle"
        }
    }
}

enum NotchSongInfoVisibility: String, CaseIterable, Identifiable, Sendable {
    case always
    case whilePlaying
    case never

    static let fallback: NotchSongInfoVisibility = .always

    var id: String { rawValue }

    var title: String {
        switch self {
        case .always:
            "Всегда"
        case .whilePlaying:
            "Только при воспроизведении"
        case .never:
            "Никогда"
        }
    }

    func shouldShow(isPlaying: Bool) -> Bool {
        switch self {
        case .always:
            true
        case .whilePlaying:
            isPlaying
        case .never:
            false
        }
    }
}

enum NotchColorSource: String, CaseIterable, Identifiable, Sendable {
    case artwork
    case systemAccent

    static let fallback: NotchColorSource = .artwork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .artwork:
            "Обложка (авто)"
        case .systemAccent:
            "Акцент системы"
        }
    }
}

enum NotchPulseMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case scale
    case glow

    static let fallback: NotchPulseMode = .off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            "Выключено"
        case .scale:
            "Масштаб"
        case .glow:
            "Свечение"
        }
    }
}

enum NotchPreferences {
    static let enabledKey = "notchEnabled"
    static let displayTargetKey = "notchDisplayTarget"
    static let widthKey = "notchWidth"
    static let heightAdjustmentKey = "notchHeightAdjustment"
    static let hapticFeedbackKey = "notchHapticFeedback"
    static let songInfoVisibilityKey = "notchSongInfoVisibility"
    static let hoverEnabledKey = "notchHoverEnabled"
    static let clickEnabledKey = "notchClickEnabled"
    static let hoverDelayKey = "notchHoverDelay"
    static let notificationsEnabledKey = "notchNotificationsEnabled"
    static let notificationDurationKey = "notchNotificationDuration"
    static let coloredProgressKey = "notchColoredProgress"
    static let coloredWaveformKey = "notchColoredWaveform"
    static let equalizerSensitivityKey = "notchEqualizerSensitivity"
    static let outlineShimmerKey = "notchOutlineShimmer"
    static let outlineWidthKey = "notchOutlineWidth"
    static let pulseModeKey = "notchPulseMode"
    static let colorSourceKey = "notchColorSource"
    static let cornerRadiusKey = "notchCornerRadius"

    static let enabledFallback = true
    static let widthFallback = 320.0
    static let widthRange = 240.0 ... 420.0
    static let widthStep = 5.0
    static let heightAdjustmentFallback = 0.0
    static let heightAdjustmentRange = -4.0 ... 12.0
    static let heightAdjustmentStep = 1.0
    static let hapticFeedbackFallback = true
    static let hoverEnabledFallback = true
    static let clickEnabledFallback = true
    static let hoverDelayFallback = 0.25
    static let hoverDelayRange = 0.1 ... 1.0
    static let hoverDelayStep = 0.05
    static let notificationsEnabledFallback = true
    static let notificationDurationFallback = 3.0
    static let notificationDurationRange = 1.0 ... 8.0
    static let notificationDurationStep = 0.25
    static let coloredProgressFallback = true
    static let coloredWaveformFallback = true
    static let equalizerSensitivityFallback = 1.0
    static let equalizerSensitivityRange = 0.5 ... 2.0
    static let equalizerSensitivityStep = 0.1
    static let outlineShimmerFallback = false
    static let outlineWidthFallback = 1.5
    static let outlineWidthRange = 1.0 ... 5.0
    static let outlineWidthStep = 0.5
    static let cornerRadiusFallback = 12.0
    static let cornerRadiusRange = 0.0 ... 20.0
    static let cornerRadiusStep = 1.0

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            enabledKey: enabledFallback,
            displayTargetKey: NotchDisplayTarget.fallback.rawValue,
            widthKey: widthFallback,
            heightAdjustmentKey: heightAdjustmentFallback,
            hapticFeedbackKey: hapticFeedbackFallback,
            songInfoVisibilityKey: NotchSongInfoVisibility.fallback.rawValue,
            hoverEnabledKey: hoverEnabledFallback,
            clickEnabledKey: clickEnabledFallback,
            hoverDelayKey: hoverDelayFallback,
            notificationsEnabledKey: notificationsEnabledFallback,
            notificationDurationKey: notificationDurationFallback,
            coloredProgressKey: coloredProgressFallback,
            coloredWaveformKey: coloredWaveformFallback,
            equalizerSensitivityKey: equalizerSensitivityFallback,
            outlineShimmerKey: outlineShimmerFallback,
            outlineWidthKey: outlineWidthFallback,
            pulseModeKey: NotchPulseMode.fallback.rawValue,
            colorSourceKey: NotchColorSource.fallback.rawValue,
            cornerRadiusKey: cornerRadiusFallback,
        ])
    }

    static func clampedOutlineWidth(_ value: Double) -> Double {
        min(max(value, outlineWidthRange.lowerBound), outlineWidthRange.upperBound)
    }

    static func clampedWidth(_ value: Double) -> Double {
        min(max(value, widthRange.lowerBound), widthRange.upperBound)
    }

    static func clampedHeightAdjustment(_ value: Double) -> Double {
        min(max(value, heightAdjustmentRange.lowerBound), heightAdjustmentRange.upperBound)
    }

    static func clampedHoverDelay(_ value: Double) -> Double {
        min(max(value, hoverDelayRange.lowerBound), hoverDelayRange.upperBound)
    }

    static func clampedNotificationDuration(_ value: Double) -> Double {
        min(max(value, notificationDurationRange.lowerBound), notificationDurationRange.upperBound)
    }

    static func clampedEqualizerSensitivity(_ value: Double) -> Double {
        min(max(value, equalizerSensitivityRange.lowerBound), equalizerSensitivityRange.upperBound)
    }

    static func clampedCornerRadius(_ value: Double) -> Double {
        min(max(value, cornerRadiusRange.lowerBound), cornerRadiusRange.upperBound)
    }

    static func compactSize(width: Double, heightAdjustment: Double) -> CGSize {
        CGSize(
            width: clampedWidth(width),
            height: 36 + clampedHeightAdjustment(heightAdjustment)
        )
    }

    static func expandedSize(width: Double, heightAdjustment: Double) -> CGSize {
        CGSize(
            width: max(clampedWidth(width) + 96, 352),
            height: 176 + clampedHeightAdjustment(heightAdjustment)
        )
    }
}

enum NotchResponsiveLayout {
    private static let revealStartHeight = 96.0
    private static let revealEndHeight = 160.0
    private static let compactOutlineOpacity = 0.24

    static let compactArtworkSize: CGFloat = 24
    static let compactEqualizerSize = CGSize(width: 24, height: 16)
    static let compactHorizontalPadding: CGFloat = 10
    static let compactEqualizerVerticalOffset: CGFloat = -2

    static func artworkSize(in containerSize: CGSize) -> CGFloat {
        let horizontalLimit = containerSize.width * 0.18
        let verticalLimit = max(32, containerSize.height - 72)
        return min(78, max(32, min(horizontalLimit, verticalLimit)))
    }

    static func revealProgress(forHeight height: CGFloat) -> Double {
        let progress = (height - revealStartHeight) / (revealEndHeight - revealStartHeight)
        return min(max(progress, 0), 1)
    }

    static func bottomCornerRadius(
        preferredRadius: Double,
        revealProgress: Double,
        height: CGFloat
    ) -> CGFloat {
        let progress = min(max(revealProgress, 0), 1)
        let radius = NotchPreferences.clampedCornerRadius(preferredRadius) + 10 * progress
        return min(CGFloat(radius), max(0, height / 2))
    }

    static func baseOutlineOpacity(revealProgress: Double) -> Double {
        let progress = min(max(revealProgress, 0), 1)
        return compactOutlineOpacity * (1 - progress)
    }
}

enum NotchMotion {
    static let resizeDuration = 0.36
    static let hoverExitGrace = 0.14
}

enum NotchExpansionPolicy {
    static func shouldExpand(
        hoverReady: Bool,
        hoverEnabled: Bool,
        isPinned: Bool,
        clickEnabled: Bool,
        notificationVisible: Bool
    ) -> Bool {
        (hoverReady && hoverEnabled)
            || (isPinned && clickEnabled)
            || notificationVisible
    }
}
