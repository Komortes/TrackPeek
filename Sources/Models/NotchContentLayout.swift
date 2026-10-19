import Foundation

enum NotchContentLayout: String, CaseIterable, Identifiable, Sendable {
    case standard, focus
    static let storageKey = "notchContentLayout"
    static let fallback: Self = .standard
    var id: String { rawValue }
    var title: String { self == .focus ? String(localized: "Focus") : String(localized: "Full Player") }
    var summary: String {
        self == .focus ? String(localized: "Track title, controls and progress. No artwork or effects.") : String(localized: "Artwork, controls and your chosen effects.")
    }
    func size(for state: NotchPanelState, width: Double, heightAdjustment: Double, topInset: Double = 0) -> CGSize {
        switch state {
        case .collapsed:
            NotchPreferences.compactSize(width: width, heightAdjustment: heightAdjustment)
        case .notification:
            self == .focus
                ? CGSize(width: NotchPreferences.clampedWidth(width) + 48,
                         height: max(64 + NotchPreferences.clampedHeightAdjustment(heightAdjustment), topInset + 32))
                : NotchPreferences.notificationSize(width: width, heightAdjustment: heightAdjustment)
        case .expanded:
            self == .focus
                ? CGSize(width: max(NotchPreferences.clampedWidth(width) + 96, 352),
                         height: 156 + NotchPreferences.clampedHeightAdjustment(heightAdjustment) + max(0, topInset - 32))
                : NotchPreferences.expandedSize(width: width, heightAdjustment: heightAdjustment)
        }
    }
}
