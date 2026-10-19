import AppKit
import Carbon

enum ShortcutAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case playPause, previousTrack, nextTrack, toggleOverlay
    var id: String { rawValue }
    var title: String {
        switch self {
        case .playPause: String(localized: "Play / Pause")
        case .previousTrack: String(localized: "Previous Track")
        case .nextTrack: String(localized: "Next Track")
        case .toggleOverlay: String(localized: "Show / Hide Panel")
        }
    }
    var subtitle: String {
        self == .toggleOverlay
            ? String(localized: "For the selected widget or notch, following its visibility rules.")
            : String(localized: "For the current Spotify or Apple Music source.")
    }
}

/// Physical key positions survive input language changes; the label uses the current layout.
struct GlobalShortcut: Codable, Equatable, Hashable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    static let supportedModifiers = UInt32(cmdKey | controlKey | optionKey | shiftKey)

    var isValid: Bool {
        keyCode < 128 && ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 72, 73, 74].contains(keyCode)
            && modifiers & ~Self.supportedModifiers == 0
            && modifiers & UInt32(cmdKey | controlKey) != 0
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        let flags = event.modifierFlags
        modifiers = (flags.contains(.command) ? UInt32(cmdKey) : 0)
            | (flags.contains(.control) ? UInt32(controlKey) : 0)
            | (flags.contains(.option) ? UInt32(optionKey) : 0)
            | (flags.contains(.shift) ? UInt32(shiftKey) : 0)
    }

    @MainActor var displayName: String {
        let prefix = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined()
        return prefix + keyName
    }

    @MainActor private var keyName: String {
        let special: [UInt32: String] = [
            36: "↩", 48: "⇥", 49: String(localized: "Space"), 51: "⌫", 53: "⎋", 64: "F17",
            65: String(localized: "Num ."), 67: String(localized: "Num *"), 69: String(localized: "Num +"), 71: "⌧", 75: String(localized: "Num /"), 76: "⌤",
            78: String(localized: "Num −"), 79: "F18", 80: "F19", 81: String(localized: "Num ="), 90: "F20",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
            105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
            114: String(localized: "Help"), 115: "↖", 116: "⇞", 117: "⌦", 118: "F4", 119: "↘", 120: "F2",
            121: "⇟", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        if let name = special[keyCode] { return name }
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        if let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
            let layout = UnsafeRawPointer(CFDataGetBytePtr(data)).assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKey: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 8)
            let result = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKey,
                characters.count, &length, &characters)
            if result == noErr, length > 0 {
                let name = String(utf16CodeUnits: characters, count: length).uppercased()
                if !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) {
                    return name
                }
            }
        }
        return String(localized: "Key \(keyCode)")
    }
}
