import SwiftUI

enum ResourceUsageMode: String, CaseIterable, Identifiable, Sendable {
    case automatic, normal, economical

    static let storageKey = "resourceUsageMode"
    static let fallback = Self.automatic
    var id: Self { self }
    var title: String {
        switch self {
        case .automatic: "Автоматически"
        case .normal: "Обычный"
        case .economical: "Экономный"
        }
    }

    func isSaving(lowPowerMode: Bool) -> Bool {
        switch self {
        case .automatic: lowPowerMode
        case .normal: false
        case .economical: true
        }
    }

    /// Only healthy background polls are slowed. Recovery backoff and denied
    /// permission retain their existing schedule; commands never use this delay.
    static func pollDelay(_ delay: TimeInterval?, availability: PlaybackAvailability, saving: Bool) -> TimeInterval? {
        guard let delay, saving, availability == .ready else { return delay }
        return delay <= 2 ? 5 : max(delay, 8)
    }
}

private struct ResourceSavingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var resourceSaving: Bool {
        get { self[ResourceSavingKey.self] }
        set { self[ResourceSavingKey.self] = newValue }
    }
}
