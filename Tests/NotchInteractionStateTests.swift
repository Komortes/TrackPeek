import Testing
@testable import TrackPeek

@Suite("Notch interaction state")
@MainActor
struct NotchInteractionStateTests {
    @Test("card layouts are always expanded regardless of hover/pin state")
    func cardLayoutAlwaysExpanded() {
        let state = NotchInteractionState()
        #expect(
            state.panelState(cardLayoutActive: true, hoverEnabled: false, clickEnabled: false)
                == .expanded
        )
    }

    @Test("pin toggles independently of hover")
    func togglePinAffectsPanelState() {
        let state = NotchInteractionState()
        #expect(
            state.panelState(cardLayoutActive: false, hoverEnabled: false, clickEnabled: true)
                == .collapsed
        )

        state.togglePin()
        #expect(
            state.panelState(cardLayoutActive: false, hoverEnabled: false, clickEnabled: true)
                == .expanded
        )

        state.togglePin()
        #expect(
            state.panelState(cardLayoutActive: false, hoverEnabled: false, clickEnabled: true)
                == .collapsed
        )
    }

    @Test("collapse resets pin regardless of how it was set")
    func collapseResetsPin() {
        let state = NotchInteractionState()
        state.togglePin()
        state.collapse()
        #expect(
            state.panelState(cardLayoutActive: false, hoverEnabled: false, clickEnabled: true)
                == .collapsed
        )
    }

    @Test("explicit close cancels a pending hover even if its delay still completes")
    func collapseCancelsDelayedHover() async {
        let delay = InteractionDelay()
        let state = NotchInteractionState(sleep: delay.sleep)
        let hover = state.handleHover(isInside: true, pointerIsInside: { true }, enabled: true, delay: 0.3)
        await delay.waitForRequest(1)

        state.collapse()
        delay.finish(1)
        await hover?.value

        #expect(!state.hoverReady)
        #expect(state.panelState(cardLayoutActive: false, hoverEnabled: true, clickEnabled: true) == .collapsed)
    }

    @Test("explicit close ignores hover until the pointer leaves and enters again")
    func closeRequiresPointerReentry() async {
        let delay = InteractionDelay()
        let state = NotchInteractionState(sleep: delay.sleep)
        let initial = state.handleHover(isInside: true, pointerIsInside: { true }, enabled: true, delay: 0.3)
        await delay.waitForRequest(1)
        delay.finish(1)
        await initial?.value
        #expect(state.hoverReady)

        state.collapse()
        let repeated = state.handleHover(isInside: true, pointerIsInside: { true }, enabled: true, delay: 0.3)
        #expect(repeated == nil)
        #expect(!state.hoverReady)

        let exit = state.handleHover(isInside: false, pointerIsInside: { false }, enabled: true, delay: 0.3)
        await delay.waitForRequest(2)
        let reentry = state.handleHover(isInside: true, pointerIsInside: { true }, enabled: true, delay: 0.3)
        await delay.waitForRequest(3)
        delay.finish(2)
        await exit?.value
        delay.finish(3)
        await reentry?.value
        #expect(state.hoverReady)
    }

    @Test("an obsolete hover cannot open after exit, and cancelled exit cannot close after reentry")
    func interruptedHoverUsesLatestPointerState() async {
        let delay = InteractionDelay()
        let state = NotchInteractionState(sleep: delay.sleep)
        let entering = state.handleHover(isInside: true, pointerIsInside: { true }, enabled: true, delay: 0.3)
        await delay.waitForRequest(1)
        let exiting = state.handleHover(isInside: false, pointerIsInside: { false }, enabled: true, delay: 0.3)
        await delay.waitForRequest(2)

        delay.finish(1)
        await entering?.value
        #expect(!state.hoverReady)

        let returning = state.handleHover(isInside: true, pointerIsInside: { true }, enabled: true, delay: 0.3)
        await delay.waitForRequest(3)
        delay.finish(3)
        await returning?.value
        #expect(state.hoverReady)

        delay.finish(2)
        await exiting?.value
        #expect(state.hoverReady)
    }

    @Test("hover checks the current pointer position after its delay")
    func hoverRevalidatesPointer() async {
        let delay = InteractionDelay()
        let state = NotchInteractionState(sleep: delay.sleep)
        var pointerInside = true
        let hover = state.handleHover(isInside: true, pointerIsInside: { pointerInside }, enabled: true, delay: 0.3)
        await delay.waitForRequest(1)
        pointerInside = false
        delay.finish(1)
        await hover?.value
        #expect(!state.hoverReady)
    }

    @Test("cancelling pending work prevents a late hover result")
    func cancellationPreventsLateHover() async {
        let delay = InteractionDelay()
        let state = NotchInteractionState(sleep: delay.sleep)
        let hover = state.handleHover(isInside: true, pointerIsInside: { true }, enabled: true, delay: 0.3)
        await delay.waitForRequest(1)
        state.cancelPendingTasks()
        delay.finish(1)
        await hover?.value
        #expect(!state.hoverReady)
    }

    @Test("pin keeps the panel expanded after hover exit and above a notification")
    func pinHasPriorityOverHoverAndNotification() async {
        let delay = InteractionDelay()
        let state = NotchInteractionState(sleep: delay.sleep)
        state.handleTrackChange(from: "first", to: "second", notificationsEnabled: true, duration: 2)
        await delay.waitForRequest(1)
        state.togglePin()
        let exit = state.handleHover(isInside: false, pointerIsInside: { false }, enabled: true, delay: 0.3)
        await delay.waitForRequest(2)
        delay.finish(2)
        await exit?.value
        #expect(state.panelState(cardLayoutActive: false, hoverEnabled: true, clickEnabled: true) == .expanded)
        state.togglePin()
        #expect(state.panelState(cardLayoutActive: false, hoverEnabled: true, clickEnabled: true) == .notification)
        state.cancelPendingTasks()
        delay.finish(1)
    }
}

/// Delays deliberately ignore cancellation; the state must reject obsolete work itself.
@MainActor
private final class InteractionDelay {
    private var requests = 0
    private var pending: [Int: CheckedContinuation<Void, Never>] = [:]
    private var observers: [(Int, CheckedContinuation<Void, Never>)] = []

    func sleep(_ duration: Duration) async {
        await withCheckedContinuation { continuation in
            requests += 1
            pending[requests] = continuation
            let ready = observers.filter { $0.0 <= requests }
            observers.removeAll { $0.0 <= requests }
            for (_, observer) in ready { observer.resume() }
        }
    }

    func waitForRequest(_ count: Int) async {
        guard requests < count else { return }
        await withCheckedContinuation { observers.append((count, $0)) }
    }

    func finish(_ request: Int) {
        pending.removeValue(forKey: request)?.resume()
    }
}
