import SwiftUI
import Testing
@testable import TrackPeek

@Suite("Local playback keyboard input")
struct PlaybackKeyboardInputTests {
    @Test("arrow-key system flags and Caps Lock do not block local playback keys")
    func acceptsSystemFlags() {
        #expect(PlaybackKeyboardInput.accepts([]))
        #expect(PlaybackKeyboardInput.accepts(.numericPad))
        #expect(PlaybackKeyboardInput.accepts(.capsLock))
        // Arrow events can carry the system-reserved Function flag. Include
        // every non-command flag without depending on its internal bit value.
        #expect(PlaybackKeyboardInput.accepts(.all.subtracting([.shift, .control, .option, .command])))
    }

    @Test("modified shortcuts remain available to the app and system",
          arguments: [EventModifiers.shift, .control, .option, .command])
    func ignoresCommandModifiers(_ modifier: EventModifiers) {
        #expect(!PlaybackKeyboardInput.accepts(modifier))
        #expect(!PlaybackKeyboardInput.accepts(modifier.union(.numericPad)))
    }
}
