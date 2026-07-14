import AppKit
import SwiftUI

@MainActor
final class TrackPeekAppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?
    let menuBarControlsController = MenuBarControlsController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotchPreferences.registerDefaults()
        MenuBarPreferences.registerDefaults()

        let controller = NotchWindowController()
        notchWindowController = controller
        controller.start()

        menuBarControlsController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchWindowController?.stop()
        menuBarControlsController.stop()
    }
}

@main
struct TrackPeekApp: App {
    @NSApplicationDelegateAdaptor(TrackPeekAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            TrackPeekPopoverView()
        } label: {
            MenuBarLabelView(controller: appDelegate.menuBarControlsController)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
