import AppKit
import Observation
import QuartzCore
import SwiftUI

@MainActor
@Observable
final class NotchPointerState {
    var isInside = false
}

@MainActor
final class NotchWindowController: NSObject {
    private let model = SpotifySpikeModel()
    private var panelHosts: [Int: NotchPanelHost] = [:]
    private var refreshTask: Task<Void, Never>?

    func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.standard
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        synchronizePanels()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        refreshTask?.cancel()
        refreshTask = nil
        removeAllPanels()
    }

    @objc nonisolated private func preferencesDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.synchronizePanels()
        }
    }

    @objc nonisolated private func screenParametersDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.synchronizePanels()
        }
    }

    private func synchronizePanels() {
        let defaults = UserDefaults.standard
        let mode = DisplayMode(
            rawValue: defaults.string(forKey: DisplayMode.storageKey) ?? DisplayMode.fallback.rawValue
        ) ?? .fallback
        let isEnabled = defaults.bool(forKey: NotchPreferences.enabledKey)

        guard mode == .notch, isEnabled else {
            removeAllPanels()
            updateRefreshTask()
            return
        }

        let target = NotchDisplayTarget(
            rawValue: defaults.string(forKey: NotchPreferences.displayTargetKey)
                ?? NotchDisplayTarget.fallback.rawValue
        ) ?? .fallback
        let targetScreens = screens(for: target)
        let targetIDs = Set(targetScreens.compactMap(screenIdentifier))

        let staleIDs = panelHosts.keys.filter { !targetIDs.contains($0) }
        for identifier in staleIDs {
            panelHosts.removeValue(forKey: identifier)?.close()
        }

        for screen in targetScreens {
            guard let identifier = screenIdentifier(screen) else { continue }

            if let host = panelHosts[identifier] {
                host.updateLayout()
                host.show()
            } else {
                let host = NotchPanelHost(screen: screen, model: model)
                panelHosts[identifier] = host
                host.show()
            }
        }

        updateRefreshTask()
    }

    private func screens(for target: NotchDisplayTarget) -> [NSScreen] {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return [] }

        switch target {
        case .mainDisplay:
            return [primary]
        case .notchedDisplay:
            let notched = screens.first {
                $0.auxiliaryTopLeftArea != nil || $0.auxiliaryTopRightArea != nil
            }
            return [notched ?? primary]
        case .allDisplays:
            return screens
        }
    }

    private func screenIdentifier(_ screen: NSScreen) -> Int? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.intValue
    }

    private func updateRefreshTask() {
        guard !panelHosts.isEmpty else {
            refreshTask?.cancel()
            refreshTask = nil
            return
        }

        guard refreshTask == nil else { return }

        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                model.refresh()

                let interval = model.track?.isPlaying == true ? 2.0 : 4.0
                try? await Task.sleep(for: .milliseconds(Int64(interval * 1_000)))
            }
        }
    }

    private func removeAllPanels() {
        panelHosts.values.forEach { $0.close() }
        panelHosts.removeAll()
    }
}

@MainActor
private final class NotchPanelHost {
    private let panel: NotchPanel
    private let pointerState = NotchPointerState()
    private let screen: NSScreen
    private var isExpanded = false

    init(screen: NSScreen, model: SpotifySpikeModel) {
        self.screen = screen
        panel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        updateLayout(animated: false)

        panel.contentView = NotchTrackingHostingView(
            rootView: NotchPlayerView(
                model: model,
                pointerState: pointerState,
                onExpansionChange: { [weak self] expanded in
                    self?.setExpanded(expanded)
                }
            ),
            pointerState: pointerState
        )
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }

    func updateLayout() {
        updateLayout(animated: false)
    }

    private func configurePanel() {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
        ]
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        updateLayout(animated: true)
    }

    private func updateLayout(animated: Bool) {
        let defaults = UserDefaults.standard
        let width = defaults.double(forKey: NotchPreferences.widthKey)
        let heightAdjustment = defaults.double(forKey: NotchPreferences.heightAdjustmentKey)
        let size = isExpanded
            ? NotchPreferences.expandedSize(width: width, heightAdjustment: heightAdjustment)
            : NotchPreferences.compactSize(width: width, heightAdjustment: heightAdjustment)
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )

        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = NotchMotion.resizeDuration
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.23,
                1,
                0.32,
                1
            )
            panel.animator().setFrame(frame, display: true)
        }
    }
}

@MainActor
private final class NotchTrackingHostingView<Content: View>: NSHostingView<Content> {
    private let pointerState: NotchPointerState
    private var notchTrackingArea: NSTrackingArea?

    init(rootView: Content, pointerState: NotchPointerState) {
        self.pointerState = pointerState
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init(rootView: Content) {
        fatalError("Use init(rootView:pointerState:)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let notchTrackingArea {
            removeTrackingArea(notchTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        notchTrackingArea = trackingArea
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        pointerState.isInside = true
    }

    override func mouseExited(with event: NSEvent) {
        pointerState.isInside = false
    }
}

private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
