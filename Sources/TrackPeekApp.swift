import AppKit
import SwiftUI

@MainActor
final class TrackPeekAppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?
    private let onboardingController = OnboardingWindowController()
    let menuBarControlsController = MenuBarControlsController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // В тест-хосте не поднимаем сервисы приложения: опрос плеера через
        // AppleScript и оконные контроллеры роняли тест-раннер (EXC_BAD_ACCESS).
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        OverlayMode.migrateIfNeeded()
        WidgetPreferences.migrateDefaultsIfNeeded()
        NotchPreferences.registerDefaults()
        WidgetPreferences.registerDefaults()
        MenuBarPreferences.registerDefaults()

        PlaybackCoordinator.shared.start()

        let controller = NotchWindowController()
        notchWindowController = controller
        controller.start()

        menuBarControlsController.start()
        _ = SparkleUpdaterController.shared

        onboardingController.showIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchWindowController?.stop()
        menuBarControlsController.stop()
        PlaybackCoordinator.shared.stop()
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
