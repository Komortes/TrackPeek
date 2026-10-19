import Foundation
import Carbon

@MainActor
protocol ShortcutRegistering: AnyObject {
    var onEvent: ((UInt32, Bool) -> Void)? { get set }
    func register(_ shortcut: GlobalShortcut, id: UInt32) throws
    func unregisterAll()
    func stop()
}

enum ShortcutRegistrationError: Error, LocalizedError {
    case unavailable
    case systemReserved
    var errorDescription: String? {
        switch self {
        case .unavailable: String(localized: "Could not enable this shortcut. Another app may be using it.")
        case .systemReserved: String(localized: "macOS uses this shortcut. Choose another one.")
        }
    }
}

/// Only registered hot-key events enter the app. No event taps, polling or keyboard monitoring.
@MainActor
final class CarbonShortcutBackend: ShortcutRegistering {
    var onEvent: ((UInt32, Bool) -> Void)?
    private var handler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []
    private static let signature: OSType = 0x5450484B // TPHK

    func register(_ shortcut: GlobalShortcut, id: UInt32) throws {
        guard !isSystemReserved(shortcut) else { throw ShortcutRegistrationError.systemReserved }
        try installHandlerIfNeeded()
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
            EventHotKeyID(signature: Self.signature, id: id), GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive), &reference)
        guard status == noErr, let reference else { throw ShortcutRegistrationError.unavailable }
        registrations.append(reference)
    }

    func unregisterAll() {
        registrations.forEach { UnregisterEventHotKey($0) }
        registrations.removeAll()
    }

    func stop() {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        onEvent = nil
    }

    private func installHandlerIfNeeded() throws {
        guard handler == nil else { return }
        var events = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotKey = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey) == noErr,
                hotKey.signature == 0x5450484B else { return OSStatus(eventNotHandledErr) }
            // Application event targets are dispatched by the main run loop.
            MainActor.assumeIsolated {
                let backend = Unmanaged<CarbonShortcutBackend>.fromOpaque(context).takeUnretainedValue()
                backend.onEvent?(hotKey.id, GetEventKind(event) == UInt32(kEventHotKeyPressed))
            }
            return noErr
        }, events.count, &events, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { throw ShortcutRegistrationError.unavailable }
    }

    private func isSystemReserved(_ shortcut: GlobalShortcut) -> Bool {
        // Familiar app commands are not listed in CopySymbolicHotKeys.
        if shortcut.modifiers == UInt32(cmdKey), [0, 1, 3, 4, 6, 7, 8, 9, 12, 13, 31, 35, 45, 46, 48, 49, 50].contains(shortcut.keyCode) {
            return true
        }
        var keys: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&keys) == noErr,
              let entries = keys?.takeRetainedValue() as? [[String: Any]] else { return false }
        return entries.contains {
            ($0[kHISymbolicHotKeyEnabled as String] as? Bool) == true
                && ($0[kHISymbolicHotKeyCode as String] as? NSNumber)?.uint32Value == shortcut.keyCode
                && ($0[kHISymbolicHotKeyModifiers as String] as? NSNumber)?.uint32Value == shortcut.modifiers
        }
    }
}
