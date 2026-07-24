import Observation
import SwiftUI

/// Владеет hover/pin/notification-состоянием чёлки и виджета отдельно от
/// вью: NotchPlayerView раньше держал это как разрозненные @State-поля и
/// вручную планировал Task'и для задержек — здесь это один тестируемый
/// узел с явными переходами, отражающий приоритет из
/// `NotchExpansionPolicy` (пин > наведение > уведомление).
@MainActor
@Observable
final class NotchInteractionState {
    private(set) var hoverReady = false
    private(set) var isPinned = false
    private(set) var notificationVisible = false

    private var hoverTask: Task<Void, Never>?
    private var notificationTask: Task<Void, Never>?

    /// `cardLayoutActive` — активна карточная раскладка виджета (она всегда
    /// развёрнута и не участвует в hover/pin-логике).
    func panelState(
        cardLayoutActive: Bool,
        hoverEnabled: Bool,
        clickEnabled: Bool
    ) -> NotchPanelState {
        if cardLayoutActive {
            return .expanded
        }
        return NotchExpansionPolicy.state(
            hoverReady: hoverReady,
            hoverEnabled: hoverEnabled,
            isPinned: isPinned,
            clickEnabled: clickEnabled,
            notificationVisible: notificationVisible
        )
    }

    func togglePin() {
        isPinned.toggle()
    }

    func collapse() {
        isPinned = false
        notificationVisible = false
        hoverReady = false
    }

    func handleHover(isInside: Bool, pointerIsInside: @escaping () -> Bool, enabled: Bool, delay: Double) {
        hoverTask?.cancel()

        guard enabled else {
            hoverReady = false
            return
        }

        guard isInside else {
            hoverTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(Int64(NotchMotion.hoverExitGrace * 1_000)))
                guard !Task.isCancelled, !pointerIsInside() else { return }
                self?.hoverReady = false
            }
            return
        }

        hoverTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int64(delay * 1_000)))
            guard !Task.isCancelled, pointerIsInside() else { return }
            self?.hoverReady = true
        }
    }

    func handleTrackChange(
        from oldValue: String?,
        to newValue: String?,
        notificationsEnabled: Bool,
        duration: Double
    ) {
        guard
            notificationsEnabled,
            oldValue != nil,
            newValue != nil,
            oldValue != newValue
        else {
            return
        }

        notificationTask?.cancel()
        notificationVisible = true

        notificationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int64(duration * 1_000)))
            guard !Task.isCancelled else { return }
            self?.notificationVisible = false
        }
    }

    func cancelPendingTasks() {
        hoverTask?.cancel()
        notificationTask?.cancel()
    }
}
