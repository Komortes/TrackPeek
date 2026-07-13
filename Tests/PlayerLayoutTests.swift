import Foundation
import Testing
@testable import TrackPeek

@Suite("Player layouts")
struct PlayerLayoutTests {
    @Test("exposes layouts in settings order")
    func exposesSettingsOrder() {
        #expect(PlayerLayout.allCases == [
            .compactHorizontal,
            .standard,
            .artworkVertical,
        ])
    }

    @Test("uses stable persisted values and a standard fallback")
    func usesStablePersistence() {
        #expect(PlayerLayout(rawValue: "compactHorizontal") == .compactHorizontal)
        #expect(PlayerLayout(rawValue: "standard") == .standard)
        #expect(PlayerLayout(rawValue: "artworkVertical") == .artworkVertical)
        #expect(PlayerLayout.fallback == .standard)
        #expect(PlayerLayout.storageKey == "playerLayout")
    }

    @Test("provides a distinct popover shape for every layout")
    func providesDistinctPopoverSizes() {
        #expect(PlayerLayout.compactHorizontal.popoverSize == CGSize(width: 390, height: 144))
        #expect(PlayerLayout.standard.popoverSize == CGSize(width: 350, height: 286))
        #expect(PlayerLayout.artworkVertical.popoverSize == CGSize(width: 310, height: 438))
    }

    @Test("popover backgrounds have stable persisted values")
    func popoverBackgroundPersistence() {
        #expect(PopoverBackgroundStyle.allCases == [.systemMaterial, .artworkBlur])
        #expect(PopoverBackgroundStyle(rawValue: "systemMaterial") == .systemMaterial)
        #expect(PopoverBackgroundStyle(rawValue: "artworkBlur") == .artworkBlur)
        #expect(PopoverBackgroundStyle.fallback == .systemMaterial)
        #expect(PopoverBackgroundStyle.storageKey == "popoverBackgroundStyle")
    }
}
