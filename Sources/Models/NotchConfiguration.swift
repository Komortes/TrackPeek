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
        ])
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

    static func compactSize(width: Double, heightAdjustment: Double) -> CGSize {
        CGSize(
            width: clampedWidth(width),
            height: 36 + clampedHeightAdjustment(heightAdjustment)
        )
    }

    static func expandedSize(width: Double, heightAdjustment: Double) -> CGSize {
        CGSize(
            width: max(clampedWidth(width) + 96, 390),
            height: 188 + clampedHeightAdjustment(heightAdjustment)
        )
    }
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
