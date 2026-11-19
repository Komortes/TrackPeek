import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()
    static let completedKey = "onboardingCompleted"

    private var window: NSWindow?

    func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.completedKey) else { return }
        let hasNotch = NSScreen.screens.contains {
            $0.auxiliaryTopLeftArea != nil || $0.auxiliaryTopRightArea != nil
        }
        Self.prepareInitialSelection(hasNotchedDisplay: hasNotch)
        show()
    }

    static func prepareInitialSelection(
        hasNotchedDisplay: Bool,
        in defaults: UserDefaults = .standard,
        domainName: String = Bundle.main.bundleIdentifier ?? "com.trackpeek.TrackPeek"
    ) {
        // Registered fallbacks also appear in object(forKey:). Only persisted
        // choices, including an explicit or migrated Menu Bar Only, take priority.
        let saved = defaults.persistentDomain(forName: domainName) ?? [:]
        guard saved[OverlayMode.storageKey] == nil else { return }
        if !hasNotchedDisplay, saved[WidgetPreferences.layoutKey] == nil {
            defaults.set(NotchWidgetLayout.miniBar.rawValue, forKey: WidgetPreferences.layoutKey)
        }
        let mode: OverlayMode = hasNotchedDisplay ? .notch : .floatingWidget
        defaults.set(mode.rawValue, forKey: OverlayMode.storageKey)
    }

    func show() {
        let window = windowForPresentation {
            NSHostingController(rootView: OnboardingView { [weak self] in
                self?.finish()
            })
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowForPresentation(content: () -> NSViewController) -> NSWindow {
        if let window { return window }
        let window = NSWindow(contentViewController: content())
        window.title = "TrackPeek"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating
        window.center()
        self.window = window
        return window
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        closing.delegate = nil
        closing.contentViewController = nil
        window = nil
    }
}
