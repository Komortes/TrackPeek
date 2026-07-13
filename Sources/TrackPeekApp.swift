import AppKit
import SwiftUI

@MainActor
final class TrackPeekAppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotchPreferences.registerDefaults()

        let controller = NotchWindowController()
        notchWindowController = controller
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchWindowController?.stop()
    }
}

@main
struct TrackPeekApp: App {
    @NSApplicationDelegateAdaptor(TrackPeekAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra("TrackPeek", systemImage: "music.note") {
            TrackPeekPopoverView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
