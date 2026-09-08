import CoreGraphics
import Foundation

enum NotchDisplayTarget: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case mainDisplay
    case notchedDisplay
    case allDisplays

    static let fallback: NotchDisplayTarget = .notchedDisplay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            "Автоматически"
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
        case .automatic:
            "wand.and.stars"
        case .mainDisplay:
            "display"
        case .notchedDisplay:
            "laptopcomputer"
        case .allDisplays:
            "rectangle.on.rectangle"
        }
    }
}

enum NotchWidgetPosition: String, CaseIterable, Identifiable, Sendable {
    // Старые raw-значения оставлены для совместимости с сохранёнными настройками.
    case topLeading = "leading"
    case topCenter = "center"
    case topTrailing = "trailing"
    case bottomLeading
    case bottomCenter
    case bottomTrailing

    static let fallback: NotchWidgetPosition = .topCenter

    var id: String { rawValue }

    var isBottom: Bool {
        switch self {
        case .bottomLeading, .bottomCenter, .bottomTrailing:
            true
        case .topLeading, .topCenter, .topTrailing:
            false
        }
    }

    /// Горизонтальное выравнивание: -1 слева, 0 центр, 1 справа.
    var horizontalAlignment: Int {
        switch self {
        case .topLeading, .bottomLeading: -1
        case .topCenter, .bottomCenter: 0
        case .topTrailing, .bottomTrailing: 1
        }
    }

    var title: String {
        switch self {
        case .topLeading: "Сверху слева"
        case .topCenter: "Сверху по центру"
        case .topTrailing: "Сверху справа"
        case .bottomLeading: "Снизу слева"
        case .bottomCenter: "Снизу по центру"
        case .bottomTrailing: "Снизу справа"
        }
    }
}

enum NotchWidgetLayout: String, CaseIterable, Identifiable, Sendable {
    case pill
    case miniBar
    case edge
    case cardHorizontal
    case cardVertical
    case artworkSquare
    case lyricsCard
    case karaokeCard
    case equalizerCard

    static let fallback: NotchWidgetLayout = .pill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pill:
            "Пилюля"
        case .edge:
            "Edge · Боковая панель"
        case .miniBar:
            "Мини-строка"
        case .cardHorizontal:
            "Обложка сбоку"
        case .cardVertical:
            "Обложка сверху"
        case .artworkSquare:
            "Квадрат-обложка"
        case .lyricsCard:
            "Текст песни"
        case .karaokeCard:
            "Караоке"
        case .equalizerCard:
            "Эквалайзер"
        }
    }

    var summary: String {
        switch self {
        case .pill:
            "Компактная полоска, раскрывается при наведении."
        case .edge:
            "Узкая панель у края экрана. Только главное."
        case .miniBar:
            "Тонкая строка: обложка, название и кнопки."
        case .cardHorizontal:
            "Полный плеер постоянного размера."
        case .cardVertical:
            "Вертикальная карточка с крупной обложкой."
        case .artworkSquare:
            "Крупная обложка с читаемой подписью и управлением."
        case .lyricsCard:
            "Компактный плеер с синхронизированным текстом."
        case .karaokeCard:
            "Крупный текст песни в несколько строк."
        case .equalizerCard:
            "Живая волна во всю карточку."
        }
    }

    /// Карточные раскладки не сворачиваются — панель всегда развёрнута.
    var isAlwaysExpanded: Bool {
        self != .pill
    }

    /// Группа назначения — используется, чтобы сначала выбрать смысл,
    /// а затем конкретный визуальный вариант внутри него.
    var family: NotchWidgetLayoutFamily {
        switch self {
        case .pill, .miniBar, .edge:
            .compact
        case .cardHorizontal, .cardVertical, .artworkSquare:
            .fullPlayer
        case .lyricsCard, .karaokeCard:
            .lyrics
        case .equalizerCard:
            .visualizer
        }
    }
}

enum NotchWidgetLayoutFamily: String, CaseIterable, Identifiable, Sendable {
    case compact
    case fullPlayer
    case lyrics
    case visualizer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: "Компактные"
        case .fullPlayer: "Полный плеер"
        case .lyrics: "Текст песни"
        case .visualizer: "Визуализация"
        }
    }

    var layouts: [NotchWidgetLayout] {
        NotchWidgetLayout.allCases.filter { $0.family == self }
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
    static let lyricsEnabledKey = "notchLyricsEnabled"

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
    static let lyricsEnabledFallback = false

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
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
            lyricsEnabledKey: lyricsEnabledFallback,
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

    /// Размер лёгкого уведомления о новом треке.
    static func notificationSize(width: Double, heightAdjustment: Double) -> CGSize {
        CGSize(
            width: min(clampedWidth(width) + 48, expandedSize(width: width, heightAdjustment: heightAdjustment).width),
            height: 64 + clampedHeightAdjustment(heightAdjustment)
        )
    }

}

enum NotchResponsiveLayout {
    private static let revealStartHeight = 96.0
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

    static func revealProgress(forHeight height: CGFloat, expandedHeight: CGFloat = 176) -> Double {
        guard expandedHeight > revealStartHeight else { return 1 }
        let progress = (height - revealStartHeight) / (expandedHeight - revealStartHeight)
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
    /// Раскрытие и закрытие асимметричны: панель быстро подтверждает
    /// намерение пользователя (ease-out) и чуть быстрее освобождает экран
    /// обратно (ease-in) — симметричные 0.42 с ощущались медленно вместе
    /// с задержкой наведения.
    static let expandDuration = 0.30
    static let collapseDuration = 0.24
    static let hoverExitGrace = 0.14

    /// Оставлено для мест, которым конкретное направление недоступно.
    static let resizeDuration = 0.42
}

/// Состояние панели: свернута, лёгкое уведомление о новом треке или полный плеер.
enum NotchPanelState: Equatable, Sendable {
    case collapsed
    case notification
    case expanded
}

enum NotchExpansionPolicy {
    /// Приоритет: ручная фиксация > наведение > уведомление > свернуто.
    /// Уведомление о новой песне больше не раскрывает полный плеер —
    /// оно показывает лёгкий вариант без контролов.
    static func state(
        hoverReady: Bool,
        hoverEnabled: Bool,
        isPinned: Bool,
        clickEnabled: Bool,
        notificationVisible: Bool
    ) -> NotchPanelState {
        if (isPinned && clickEnabled) || (hoverReady && hoverEnabled) {
            return .expanded
        }
        if notificationVisible {
            return .notification
        }
        return .collapsed
    }

    static func shouldExpand(
        hoverReady: Bool,
        hoverEnabled: Bool,
        isPinned: Bool,
        clickEnabled: Bool,
        notificationVisible: Bool
    ) -> Bool {
        state(
            hoverReady: hoverReady,
            hoverEnabled: hoverEnabled,
            isPinned: isPinned,
            clickEnabled: clickEnabled,
            notificationVisible: notificationVisible
        ) == .expanded
    }
}
