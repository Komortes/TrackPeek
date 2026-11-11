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
    @ObservationIgnored private var pointerInside = false
    @ObservationIgnored private var hoverSuppressed = false
    private let sleep: @MainActor (Duration) async throws -> Void

    init(sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

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
        if isPinned { hoverSuppressed = false }
    }

    func collapse() {
        cancelPendingTasks()
        // A resize can report another hover while the pointer is still over the panel.
        hoverSuppressed = pointerInside
        isPinned = false
        notificationVisible = false
        hoverReady = false
    }

    @discardableResult
    func handleHover(isInside: Bool, pointerIsInside: @escaping () -> Bool, enabled: Bool, delay: Double) -> Task<Void, Never>? {
        hoverTask?.cancel()
        hoverTask = nil
        pointerInside = pointerIsInside()
        if !pointerInside { hoverSuppressed = false }

        guard enabled else {
            hoverReady = false
            return nil
        }

        guard !hoverSuppressed else {
            hoverReady = false
            return nil
        }

        let sleep = sleep
        guard isInside else {
            hoverTask = Task { @MainActor [weak self] in
                try? await sleep(.seconds(NotchMotion.hoverExitGrace))
                guard !Task.isCancelled, !pointerIsInside() else { return }
                self?.hoverReady = false
            }
            return hoverTask
        }

        hoverTask = Task { @MainActor [weak self] in
            try? await sleep(.seconds(delay))
            guard !Task.isCancelled, pointerIsInside() else { return }
            self?.hoverReady = true
        }
        return hoverTask
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

        let sleep = sleep
        notificationTask = Task { @MainActor [weak self] in
            try? await sleep(.seconds(duration))
            guard !Task.isCancelled else { return }
            self?.notificationVisible = false
        }
    }

    func cancelPendingTasks() {
        hoverTask?.cancel()
        hoverTask = nil
        notificationTask?.cancel()
        notificationTask = nil
    }
}
