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

    @Test("focuses settings after requesting them on the next run loop")
    @MainActor
    func focusesSettingsAfterPresentingThem() async {
        var settingsWasRequested = false
        var focusFollowedSettingsRequest = false

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            SettingsWindowPresentation.present(
                openSettings: {
                    settingsWasRequested = true
                },
                focusSettingsWindow: {
                    focusFollowedSettingsRequest = settingsWasRequested
                    continuation.resume()
                }
            )
        }

        #expect(settingsWasRequested)
        #expect(focusFollowedSettingsRequest)
    }

    @Test("recognizes only the native titled settings window")
    @MainActor
    func recognizesNativeSettingsWindow() {
        let settingsWindow = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let utilityPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        #expect(SettingsWindowPresentation.isSettingsWindow(settingsWindow))
        #expect(!SettingsWindowPresentation.isSettingsWindow(utilityPanel))

        settingsWindow.close()
        utilityPanel.close()
    }

    @Test("player state changes use short coordinated motion")
    func playerStateMotionStaysCoordinated() {
        #expect(PlayerMotion.playbackDuration == 0.24)
        #expect(PlayerMotion.controlDuration == 0.14)
        #expect(PlayerMotion.equalizerDuration == 0.28)
        #expect(PlayerMotion.controlDuration < PlayerMotion.playbackDuration)
        #expect(PlayerMotion.equalizerDuration <= 0.3)
    }
}
