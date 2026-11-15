import Foundation

/// Content fades independently of its layout: each state keeps its final dimensions.
struct NotchContentPresentation: Equatable {
    let compact: Double
    let notification: Double
    let expanded: Double

    init(state: NotchPanelState) {
        compact = state == .collapsed ? 1 : 0
        notification = state == .notification ? 1 : 0
        expanded = state == .expanded ? 1 : 0
    }

    private init(compact: Double, notification: Double, expanded: Double) {
        self.compact = compact
        self.notification = notification
        self.expanded = expanded
    }

    /// Let the outgoing title disappear before revealing a differently positioned title.
    func opacity(for state: NotchPanelState) -> Double {
        let weight: Double = switch state {
        case .collapsed: compact
        case .notification: notification
        case .expanded: expanded
        }
        let progress = min(max(weight * 2 - 1, 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    func interpolated(to target: Self, progress: Double) -> Self {
        let progress = min(max(progress, 0), 1)
        return Self(
            compact: compact + (target.compact - compact) * progress,
            notification: notification + (target.notification - notification) * progress,
            expanded: expanded + (target.expanded - expanded) * progress
        )
    }
}

struct NotchContentSizes {
    let compact: CGSize
    let notification: CGSize
    let expanded: CGSize

    init(layout: NotchContentLayout, width: Double, heightAdjustment: Double, topInset: Double) {
        compact = layout.size(for: .collapsed, width: width, heightAdjustment: heightAdjustment, topInset: topInset)
        notification = layout.size(for: .notification, width: width, heightAdjustment: heightAdjustment, topInset: topInset)
        expanded = layout.size(for: .expanded, width: width, heightAdjustment: heightAdjustment, topInset: topInset)
    }
}
