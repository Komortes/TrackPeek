import AppKit
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
        #expect(PlayerLayout.artworkVertical.popoverSize == CGSize(width: 310, height: 475))
    }

    @Test("artwork size preference uses safe persisted bounds")
    func artworkSizePreferenceBounds() {
        #expect(ArtworkSizePreference.storageKey == "artworkSize")
        #expect(ArtworkSizePreference.fallback == 250)
        #expect(ArtworkSizePreference.range == 210 ... 274)
        #expect(ArtworkSizePreference.step == 2)
        #expect(ArtworkSizePreference.clamped(180) == 210)
        #expect(ArtworkSizePreference.clamped(242) == 242)
        #expect(ArtworkSizePreference.clamped(300) == 274)
    }

    @Test("artwork layout height follows the selected artwork size")
    func artworkLayoutHeightFollowsArtworkSize() {
        #expect(
            PlayerLayout.artworkVertical.popoverSize(artworkSize: 210)
                == CGSize(width: 310, height: 435)
        )
        #expect(
            PlayerLayout.artworkVertical.popoverSize(artworkSize: 274)
                == CGSize(width: 310, height: 499)
        )
        #expect(
            PlayerLayout.standard.popoverSize(artworkSize: 274)
                == PlayerLayout.standard.popoverSize
        )
    }

    @Test("popover backgrounds have stable persisted values")
    func popoverBackgroundPersistence() {
        #expect(PopoverBackgroundStyle.allCases == [.systemMaterial, .artworkBlur])
        #expect(PopoverBackgroundStyle(rawValue: "systemMaterial") == .systemMaterial)
        #expect(PopoverBackgroundStyle(rawValue: "artworkBlur") == .artworkBlur)
        #expect(PopoverBackgroundStyle.fallback == .systemMaterial)
        #expect(PopoverBackgroundStyle.storageKey == "popoverBackgroundStyle")
    }

    @Test("settings tabs use available macOS system symbols")
    func settingsTabSymbolsAreAvailable() {
        for tab in SettingsTab.allCases {
            #expect(
                NSImage(
                    systemSymbolName: tab.symbolName,
                    accessibilityDescription: tab.title
                ) != nil
            )
        }
    }
}
