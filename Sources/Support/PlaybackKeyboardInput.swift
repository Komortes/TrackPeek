import SwiftUI

enum PlaybackKeyboardInput {
    static func accepts(_ modifiers: EventModifiers) -> Bool {
        // macOS arrow events include a system Function flag. Caps Lock and
        // numeric-pad flags likewise do not turn these keys into shortcuts.
        modifiers.intersection([.shift, .control, .option, .command]).isEmpty
    }
}
