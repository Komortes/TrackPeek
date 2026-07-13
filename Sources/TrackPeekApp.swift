import SwiftUI

@main
struct TrackPeekApp: App {
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
