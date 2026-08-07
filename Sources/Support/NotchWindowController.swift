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
@Observable
final class NotchPanelLayoutState {
    private(set) var size: CGSize

    init(size: CGSize) {
        self.size = size
    }

    func updateVisibleSize(_ newSize: CGSize) {
        guard
            newSize.width.isFinite,
            newSize.height.isFinite,
            newSize.width > 0,
            newSize.height > 0,
            newSize != size
        else {
            return
        }

        size = newSize
    }
}

@MainActor
final class NotchWindowController: NSObject {
    private let coordinator = PlaybackCoordinator.shared
    private var panelHosts: [Int: NotchPanelHost] = [:]
    private var isStopped = false

    func start() {
        isStopped = false
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
        observePlayback()
    }

    func stop() {
        isStopped = true
        NotificationCenter.default.removeObserver(self)
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
        let mode = OverlayMode(
            rawValue: defaults.string(forKey: OverlayMode.storageKey) ?? OverlayMode.fallback.rawValue
        ) ?? .fallback
        let policy = OverlayVisibilityPolicy(
            rawValue: defaults.string(forKey: OverlayVisibilityPolicy.storageKey)
                ?? OverlayVisibilityPolicy.fallback.rawValue
        ) ?? .fallback

        guard OverlayVisibility.isVisible(
            mode: mode,
            temporarilyHidden: defaults.bool(forKey: OverlayVisibility.temporarilyHiddenKey),
            policy: policy,
            availability: coordinator.model.availability,
            isPlaying: coordinator.model.track?.isPlaying == true
        ) else {
            removeAllPanels()
            return
        }

        let targetKey = mode == .floatingWidget
            ? WidgetPreferences.displayTargetKey
            : NotchPreferences.displayTargetKey
        let target = NotchDisplayTarget(
            rawValue: defaults.string(forKey: targetKey)
                ?? NotchDisplayTarget.fallback.rawValue
        ) ?? .fallback
        let targetScreens = screens(for: target, mode: mode)
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
                let host = NotchPanelHost(
                    screen: screen,
                    model: coordinator.model,
                    audioMonitor: coordinator.audioMonitor,
                    lyricsStore: coordinator.lyricsStore
                )
                panelHosts[identifier] = host
                host.show()
            }
        }
    }

    /// Политики whileSourceRunning/whilePlaying зависят от playback-снапшота;
    /// пересинхронизируем панели при его изменении. withObservationTracking
    /// одноразовый — перевзводим подписку после каждого срабатывания.
    private func observePlayback() {
        withObservationTracking { [weak self] in
            guard let self else { return }
            _ = coordinator.model.availability
            _ = coordinator.model.track?.isPlaying
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !isStopped else { return }
                synchronizePanels()
                observePlayback()
            }
        }
    }

    private func screens(for target: NotchDisplayTarget, mode: OverlayMode) -> [NSScreen] {
        let screens = NSScreen.screens
        let descriptors = screens.compactMap { screen -> DisplayDescriptor? in
            guard let id = screenIdentifier(screen) else { return nil }
            return DisplayDescriptor(
                id: id,
                hasNotch: screen.auxiliaryTopLeftArea != nil
                    || screen.auxiliaryTopRightArea != nil,
                isBuiltIn: CGDisplayIsBuiltin(UInt32(id)) != 0
            )
        }
        let ids = OverlayDisplayResolver.resolveIDs(
            surface: mode == .floatingWidget ? .floatingWidget : .notch,
            target: target,
            displays: descriptors
        )
        return screens.filter { screen in
            guard let id = screenIdentifier(screen) else { return false }
            return ids.contains(id)
        }
    }

    private func screenIdentifier(_ screen: NSScreen) -> Int? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.intValue
    }

    private func removeAllPanels() {
        panelHosts.values.forEach { $0.close() }
        panelHosts.removeAll()
    }
}

@MainActor
private final class NotchPanelHost: NSObject {
    private let panel: NotchPanel
    private let pointerState = NotchPointerState()
    private let layoutState: NotchPanelLayoutState
    private let screen: NSScreen
    private var panelState: NotchPanelState = .collapsed
    /// Отличает программные setFrame от перетаскивания пользователем.
    private var isApplyingLayout = false

    init(
        screen: NSScreen,
        model: SpotifySpikeModel,
        audioMonitor: SpotifyAudioMonitor,
        lyricsStore: LyricsStore
    ) {
        self.screen = screen
        let defaults = UserDefaults.standard
        layoutState = NotchPanelLayoutState(
            size: NotchPreferences.compactSize(
                width: defaults.double(forKey: NotchPreferences.widthKey),
                heightAdjustment: defaults.double(
                    forKey: NotchPreferences.heightAdjustmentKey
                )
            )
        )
        panel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init()

        configurePanel()
        updateLayout(animated: false)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        panel.contentView = NotchTrackingHostingView(
            rootView: NotchPlayerView(
                model: model,
                audioMonitor: audioMonitor,
                lyricsStore: lyricsStore,
                pointerState: pointerState,
                panelLayoutState: layoutState,
                onStateChange: { [weak self] state in
                    self?.setPanelState(state)
                }
            ),
            pointerState: pointerState,
            layoutState: layoutState
        )
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func close() {
        NotificationCenter.default.removeObserver(self)
        panel.orderOut(nil)
    }

    /// Пользователь перетащил виджет — запоминаем позицию (верхний край,
    /// чтобы раскрытие пилюли по-прежнему росло вниз).
    @objc nonisolated private func panelDidMove(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard
                let self,
                !isApplyingLayout,
                UserDefaults.standard.bool(forKey: WidgetPreferences.freeMoveKey)
            else {
                return
            }

            let frame = panel.frame
            let layout = NotchWidgetLayout(
                rawValue: UserDefaults.standard.string(forKey: WidgetPreferences.layoutKey)
                    ?? NotchWidgetLayout.fallback.rawValue
            ) ?? .fallback
            WidgetPlacementStore.save(
                WidgetPlacement(x: Double(frame.origin.x), topY: Double(frame.maxY)),
                display: DisplayIdentity.persistentIdentifier(for: screen),
                layout: layout
            )
        }
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

    private func setPanelState(_ state: NotchPanelState) {
        guard panelState != state else { return }
        panelState = state
        updateLayout(animated: true)
    }

    private func updateLayout(animated: Bool) {
        let defaults = UserDefaults.standard
        let mode = OverlayMode(
            rawValue: defaults.string(forKey: OverlayMode.storageKey) ?? OverlayMode.fallback.rawValue
        ) ?? .fallback
        // Виджет использует собственную ширину; коррекция высоты относится
        // только к геометрии физической чёлки.
        let width = mode == .floatingWidget
            ? defaults.double(forKey: WidgetPreferences.widthKey)
            : defaults.double(forKey: NotchPreferences.widthKey)
        let heightAdjustment = mode == .floatingWidget
            ? 0
            : defaults.double(forKey: NotchPreferences.heightAdjustmentKey)
        let size: CGSize = switch panelState {
        case .expanded:
            NotchPreferences.expandedSize(width: width, heightAdjustment: heightAdjustment)
        case .notification:
            NotchPreferences.notificationSize(width: width, heightAdjustment: heightAdjustment)
        case .collapsed:
            NotchPreferences.compactSize(width: width, heightAdjustment: heightAdjustment)
        }
        let frame: NSRect

        if mode == .floatingWidget {
            let layout = NotchWidgetLayout(
                rawValue: defaults.string(forKey: WidgetPreferences.layoutKey)
                    ?? NotchWidgetLayout.fallback.rawValue
            ) ?? .fallback
            // Карточные раскладки держат постоянный размер, пилюля — как чёлка.
            let widgetSize = layout.isAlwaysExpanded
                ? WidgetPreferences.cardSize(
                    layout: layout,
                    width: width,
                    heightAdjustment: heightAdjustment
                )
                : size

            let freeMove = defaults.bool(forKey: WidgetPreferences.freeMoveKey)
            let locked = defaults.bool(forKey: WidgetPreferences.positionLockedKey)
            panel.isMovable = freeMove && !locked
            panel.isMovableByWindowBackground = freeMove && !locked

            panel.level = defaults.bool(forKey: WidgetPreferences.alwaysOnTopKey)
                ? NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
                : .normal
            var behavior: NSWindow.CollectionBehavior = [.stationary]
            behavior.insert(
                defaults.bool(forKey: WidgetPreferences.allSpacesKey)
                    ? .canJoinAllSpaces
                    : .moveToActiveSpace
            )
            if !defaults.bool(forKey: WidgetPreferences.hideInFullscreenKey) {
                behavior.insert(.fullScreenAuxiliary)
            }
            panel.collectionBehavior = behavior

            let bounds = screen.visibleFrame
            let margin = WidgetPreferences.edgeMargin
            var origin: CGPoint

            if freeMove,
               let stored = WidgetPlacementStore.placement(
                   display: DisplayIdentity.persistentIdentifier(for: screen),
                   layout: layout
               ) {
                // Пользовательская позиция: закреплён верхний край, чтобы
                // раскрытие пилюли росло вниз, как у чёлки.
                origin = CGPoint(x: stored.x, y: stored.topY - widgetSize.height)
            } else {
                let position = NotchWidgetPosition(
                    rawValue: defaults.string(forKey: WidgetPreferences.positionKey)
                        ?? NotchWidgetPosition.fallback.rawValue
                ) ?? .fallback
                let x: CGFloat = switch position.horizontalAlignment {
                case ..<0:
                    bounds.minX + margin
                case 0:
                    bounds.midX - widgetSize.width / 2
                default:
                    bounds.maxX - widgetSize.width - margin
                }
                let y = position.isBottom
                    ? bounds.minY + WidgetPreferences.topInset
                    : bounds.maxY - widgetSize.height - WidgetPreferences.topInset
                origin = CGPoint(x: x, y: y)
            }

            origin.x = min(max(origin.x, bounds.minX), bounds.maxX - widgetSize.width)
            origin.y = min(max(origin.y, bounds.minY), bounds.maxY - widgetSize.height)
            frame = NSRect(origin: origin, size: widgetSize)
        } else {
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isMovable = false
            panel.isMovableByWindowBackground = false
            frame = NSRect(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.maxY - size.height,
                width: size.width,
                height: size.height
            )
        }

        isApplyingLayout = true

        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(frame, display: true)
            isApplyingLayout = false
            syncPointerState()
            return
        }

        // Растёт панель или сжимается — разная длительность и кривая
        // (см. NotchMotion): раскрытие подтверждает намерение быстро,
        // закрытие чуть быстрее освобождает экран.
        let isGrowing = frame.height >= panel.frame.height
        let duration = isGrowing ? NotchMotion.expandDuration : NotchMotion.collapseDuration
        let controlPoints: (Float, Float, Float, Float) = isGrowing
            ? (0.16, 1, 0.3, 1)
            : (0.4, 0, 1, 1)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: controlPoints.0,
                controlPoints.1,
                controlPoints.2,
                controlPoints.3
            )
            panel.animator().setFrame(frame, display: true)
        } completionHandler: {
            // Ресайз панели под неподвижным курсором генерирует ложные
            // enter/exit; после анимации сверяемся с реальным положением мыши,
            // иначе панель может зациклиться в открытии/закрытии.
            MainActor.assumeIsolated { [weak self] in
                self?.isApplyingLayout = false
                self?.syncPointerState()
            }
        }
    }

    private func syncPointerState() {
        let inside = panel.frame.contains(NSEvent.mouseLocation)
        if pointerState.isInside != inside {
            pointerState.isInside = inside
        }
    }
}

@MainActor
private final class NotchTrackingHostingView<Content: View>: NSHostingView<Content> {
    private let pointerState: NotchPointerState
    private let layoutState: NotchPanelLayoutState
    private var notchTrackingArea: NSTrackingArea?

    init(
        rootView: Content,
        pointerState: NotchPointerState,
        layoutState: NotchPanelLayoutState
    ) {
        self.pointerState = pointerState
        self.layoutState = layoutState
        super.init(rootView: rootView)
        sizingOptions = []
    }

    @available(*, unavailable)
    required init(rootView: Content) {
        fatalError("Use init(rootView:pointerState:layoutState:)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        layoutState.updateVisibleSize(bounds.size)
        super.layout()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        guard notchTrackingArea == nil else { return }

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
        syncPointerState()
    }

    override func mouseExited(with event: NSEvent) {
        syncPointerState()
    }

    /// Не доверяем самим событиям enter/exit: во время анимации ресайза окна
    /// AppKit шлёт их и под неподвижным курсором. Истина — реальное положение
    /// мыши относительно текущего фрейма окна.
    private func syncPointerState() {
        let inside = window.map { $0.frame.contains(NSEvent.mouseLocation) } ?? false
        if pointerState.isInside != inside {
            pointerState.isInside = inside
        }
    }
}

private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
