import AppKit
import Observation

@MainActor
@Observable
final class GlobalShortcutsController: NSObject {
    static let bindingsKey = "globalShortcutBindings"
    static let enabledKey = "globalShortcutsEnabled"
    static let shared = GlobalShortcutsController { action in
        if action == .toggleOverlay {
            let defaults = UserDefaults.standard
            guard let mode = defaults.string(forKey: OverlayMode.storageKey), mode != OverlayMode.off.rawValue else { return }
            defaults.set(!defaults.bool(forKey: OverlayVisibility.temporarilyHiddenKey),
                         forKey: OverlayVisibility.temporarilyHiddenKey)
            return
        }
        let coordinator = PlaybackCoordinator.shared
        guard !coordinator.isSleeping else { return }
        Task {
            switch action {
            case .playPause: await coordinator.model.togglePlayback()
            case .previousTrack: await coordinator.model.previousTrack()
            case .nextTrack: await coordinator.model.nextTrack()
            case .toggleOverlay: break
            }
        }
    }

    private(set) var bindings: [ShortcutAction: GlobalShortcut] = [:]
    private(set) var isEnabled = true
    private(set) var recordingAction: ShortcutAction?
    private(set) var errors: [ShortcutAction: String] = [:]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let backend: any ShortcutRegistering
    @ObservationIgnored private let perform: (ShortcutAction) -> Void
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var nextID: UInt32 = 0
    @ObservationIgnored private var actionsByID: [UInt32: ShortcutAction] = [:]
    @ObservationIgnored private var pressedIDs: Set<UInt32> = []

    init(defaults: UserDefaults = .standard, backend: any ShortcutRegistering = CarbonShortcutBackend(),
         perform: @escaping (ShortcutAction) -> Void) {
        self.defaults = defaults
        self.backend = backend
        self.perform = perform
        super.init()
        reloadPreferences()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        backend.onEvent = { [weak self] id, pressed in self?.receive(id: id, pressed: pressed) }
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged),
            name: UserDefaults.didChangeNotification, object: defaults)
        // Reset held-key state after sleep; lost key-up events must not disable a shortcut.
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)
        reloadPreferences()
        applyRegistrations()
    }

    func stop() {
        isStarted = false
        recordingAction = nil
        actionsByID.removeAll()
        pressedIDs.removeAll()
        backend.stop()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func setEnabled(_ enabled: Bool) {
        recordingAction = nil
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        applyRegistrations()
    }

    func beginRecording(_ action: ShortcutAction) {
        guard isStarted else { return }
        recordingAction = action
        applyRegistrations()
    }

    func endRecording() {
        guard recordingAction != nil else { return }
        recordingAction = nil
        applyRegistrations()
    }

    /// Probe before persisting. Failed replacements leave the previous binding intact.
    @discardableResult
    func assign(_ shortcut: GlobalShortcut?, to action: ShortcutAction) -> String? {
        var candidateID: UInt32?
        if let shortcut {
            guard shortcut.isValid else { return "Добавьте ⌘ Command или ⌃ Control к обычной клавише." }
            if let duplicate = ShortcutAction.allCases.first(where: { $0 != action && bindings[$0] == shortcut }) {
                return "Уже назначено: \(duplicate.title)."
            }
            clearRegistrations()
            do {
                let id = newID()
                try backend.register(shortcut, id: id)
                candidateID = id
            } catch {
                applyRegistrations()
                return error.localizedDescription
            }
        }
        bindings[action] = shortcut
        let stored = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: Self.bindingsKey) }
        recordingAction = nil
        if isStarted, isEnabled, let candidateID {
            // Keep the successful registration alive across persistence. Registering it
            // a second time could lose the chord to another process after the probe.
            errors.removeAll()
            actionsByID[candidateID] = action
            registerBindings(excluding: action)
        } else {
            applyRegistrations()
        }
        return nil
    }

    func retryRegistration() { applyRegistrations() }

    func reloadPreferences() {
        let enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        let stored = defaults.data(forKey: Self.bindingsKey)
            .flatMap { try? JSONDecoder().decode([String: GlobalShortcut].self, from: $0) } ?? [:]
        var loaded: [ShortcutAction: GlobalShortcut] = [:]
        for action in ShortcutAction.allCases {
            if let shortcut = stored[action.rawValue], shortcut.isValid, !loaded.values.contains(shortcut) {
                loaded[action] = shortcut
            }
        }
        guard loaded != bindings || enabled != isEnabled else { return }
        bindings = loaded
        isEnabled = enabled
        recordingAction = nil
        applyRegistrations()
    }

    private func applyRegistrations() {
        clearRegistrations()
        errors.removeAll()
        guard isStarted, isEnabled, recordingAction == nil else { return }
        registerBindings()
    }

    private func registerBindings(excluding excludedAction: ShortcutAction? = nil) {
        for action in ShortcutAction.allCases {
            guard action != excludedAction, let shortcut = bindings[action] else { continue }
            let id = newID()
            do {
                try backend.register(shortcut, id: id)
                actionsByID[id] = action
            } catch { errors[action] = error.localizedDescription }
        }
    }

    private func clearRegistrations() {
        actionsByID.removeAll()
        pressedIDs.removeAll()
        backend.unregisterAll()
    }

    private func newID() -> UInt32 {
        nextID &+= 1
        return nextID
    }

    private func receive(id: UInt32, pressed: Bool) {
        guard isStarted, isEnabled, recordingAction == nil, let action = actionsByID[id] else { return }
        if !pressed { pressedIDs.remove(id); return }
        guard pressedIDs.insert(id).inserted else { return }
        perform(action)
    }

    @objc nonisolated private func preferencesChanged(_ notification: Notification) {
        Task { @MainActor [weak self] in self?.reloadPreferences() }
    }

    @objc nonisolated private func didWake(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self, self.isStarted else { return }
            self.recordingAction = nil
            self.applyRegistrations()
        }
    }
}
