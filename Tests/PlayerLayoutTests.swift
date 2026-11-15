import AppKit
import Foundation
import SwiftUI
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
            .lyrics,
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
        // close() у окна с isReleasedWhenClosed (default для NSWindow) делает
        // самостоятельный release; вместе с ARC это double-release и падение
        // всего тест-раннера при следующем дренаже autorelease-пула.
        settingsWindow.isReleasedWhenClosed = false
        utilityPanel.isReleasedWhenClosed = false

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


extension PlayerLayoutTests {
    @Test("focus has smaller bounds without changing the existing layout")
    func focusSizing() {
        #expect(NotchContentLayout.fallback == .standard)
        #expect(NotchContentLayout(rawValue: "focus") == .focus)
        for width in [240.0, 320, 420] {
            for adjustment in [-4.0, 0, 12] {
                let normal = NotchContentLayout.standard.size(for: .expanded, width: width, heightAdjustment: adjustment)
                #expect(normal == NotchPreferences.expandedSize(width: width, heightAdjustment: adjustment))
                let focus = NotchContentLayout.focus.size(for: .expanded, width: width, heightAdjustment: adjustment, topInset: 32)
                #expect(focus.width == normal.width)
                #expect(focus.height == normal.height - 20)
                #expect(focus.height >= 152)
            }
        }
        #expect(NotchContentLayout.focus.size(for: .notification, width: 320, heightAdjustment: -4, topInset: 40).height == 72)
        #expect(NotchContentLayout.focus.size(for: .expanded, width: 320, heightAdjustment: 0, topInset: 40).height == 164)
    }

    @Test("full lyrics retain compact popover bounds")
    func lyricsPopoverSizing() {
        #expect(PlayerLayout.lyrics.popoverSize(artworkSize: 274) == CGSize(width: 380, height: 470))
    }
}

extension PlayerLayoutTests {
    @Test("settings rows tolerate diagnostic controls that are conditionally absent", arguments: [false, true])
    @MainActor
    func settingsRowWithOptionalControl(showsControl: Bool) throws {
        let renderer = ImageRenderer(content: SettingsRow(title: "Player Access", subtitle: "Connected") {
            if showsControl {
                Color.red.frame(width: 120, height: 24)
            }
        }.frame(width: 430))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        #expect(image.width == 430)
        #expect(image.height >= 44 && image.height < 80)
    }

    @Test("narrow settings rows place wide controls below long translated labels")
    @MainActor
    func narrowSettingsRowStacksControl() throws {
        let bounds = try settingsRowBounds(width: 430, controlWidth: 300)

        #expect(bounds.label.maxY + 6 <= bounds.control.minY)
        #expect(abs(bounds.label.minX - bounds.control.minX) <= 3)
        #expect(bounds.label.width > 220, "The translation should use the row width instead of a squeezed column")
        #expect(bounds.control.width == 300)
    }

    @Test("wide settings rows keep controls beside the label and aligned to the trailing edge")
    @MainActor
    func wideSettingsRowRemainsHorizontal() throws {
        let bounds = try settingsRowBounds(width: 680, controlWidth: 300)

        #expect(bounds.label.maxX < bounds.control.minX)
        #expect(bounds.label.minY < bounds.control.maxY && bounds.control.minY < bounds.label.maxY)
        #expect(abs(bounds.control.maxX - 666) <= 1)
        #expect(bounds.control.width == 300)
    }

    @Test("short settings labels and toggle-sized controls remain on one line in narrow rows")
    @MainActor
    func shortSettingsRowRemainsHorizontal() throws {
        let bounds = try settingsRowBounds(width: 430, controlWidth: 44, title: "On Hover", subtitle: "")

        #expect(bounds.label.maxX < bounds.control.minX)
        #expect(bounds.label.minY < bounds.control.maxY && bounds.control.minY < bounds.label.maxY)
        #expect(abs(bounds.control.maxX - 416) <= 1)
    }

    /// Render the real row with a colored control stand-in. Pixel bounds verify
    /// the resulting arrangement without depending on its layout implementation.
    @MainActor
    private func settingsRowBounds(
        width: CGFloat,
        controlWidth: CGFloat,
        title: String = "Показывать панель воспроизведения",
        subtitle: String = "Выбранный дисплей отключён. Настройка сохранится до его повторного подключения."
    ) throws -> (label: CGRect, control: CGRect) {
        let content = SettingsRow(title: title, subtitle: subtitle) {
            Color.red.frame(width: controlWidth, height: 24)
        }
        .frame(width: width)
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
        .background(.white)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        #expect(bitmap.pixelsWide == Int(width))

        var label = CGRect.null
        var control = CGRect.null
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.9 else { continue }
                let red = color.redComponent
                let green = color.greenComponent
                let blue = color.blueComponent
                let pixel = CGRect(x: x, y: y, width: 1, height: 1)
                if red > 0.7 && green < 0.4 && blue < 0.4 {
                    control = control.union(pixel)
                } else if max(red, green, blue) < 0.7 && max(red, green, blue) - min(red, green, blue) < 0.08 {
                    label = label.union(pixel)
                }
            }
        }
        try #require(!label.isNull, "Expected visible label text")
        try #require(!control.isNull, "Expected visible control")
        return (label, control)
    }
}
