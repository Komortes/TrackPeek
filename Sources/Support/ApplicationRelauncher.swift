import AppKit

@MainActor
enum ApplicationRelauncher {
    static let settingsArgument = "--show-settings"

    static func relaunch() async throws {
        try await relaunch(
            releaseShortcuts: { GlobalShortcutsController.shared.stop() },
            launch: {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.createsNewApplicationInstance = true
                configuration.activates = true
                configuration.allowsRunningApplicationSubstitution = false
                configuration.arguments = [settingsArgument]
                _ = try await NSWorkspace.shared.openApplication(
                    at: Bundle.main.bundleURL,
                    configuration: configuration
                )
            },
            restoreShortcuts: { GlobalShortcutsController.shared.start() },
            terminate: { NSApp.terminate(nil) }
        )
    }

    // Launch Services can start the replacement before the old process exits.
    // Release its exclusive shortcuts first, but keep this app if launch fails.
    static func relaunch(
        releaseShortcuts: @MainActor () -> Void,
        launch: @MainActor () async throws -> Void,
        restoreShortcuts: @MainActor () -> Void,
        terminate: @MainActor () -> Void
    ) async throws {
        releaseShortcuts()
        do {
            try await launch()
        } catch {
            restoreShortcuts()
            throw error
        }
        terminate()
    }
}
