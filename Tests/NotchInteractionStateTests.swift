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
}
