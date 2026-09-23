import Foundation
import Testing
@testable import TrackPeek

@MainActor
@Suite("Global shortcuts")
struct GlobalShortcutsTests {
    private let chord = GlobalShortcut(keyCode: 35, modifiers: 256 | 512)

    @Test func emptyDefaultsDoNotCaptureKeys() {
        let f = ShortcutFixture(); defer { f.stop() }
        #expect(f.controller.bindings.isEmpty)
        #expect(f.backend.registered.isEmpty)
    }

    @Test func assignmentPersistsAndDuplicatesKeepPreviousBinding() {
        let f = ShortcutFixture(); defer { f.stop() }
        #expect(f.controller.assign(chord, to: .playPause) == nil)
        #expect(f.controller.assign(chord, to: .nextTrack) != nil)
        #expect(f.controller.bindings[.nextTrack] == nil)
        #expect(f.controller.bindings[.playPause] == chord)
        let restored = GlobalShortcutsController(defaults: f.defaults, backend: FakeShortcutBackend(), perform: { _ in })
        #expect(restored.bindings[.playPause] == chord)
    }

    @Test func failedReplacementKeepsWorkingBinding() {
        let f = ShortcutFixture(); defer { f.stop() }
        #expect(f.controller.assign(chord, to: .playPause) == nil)
        let occupied = GlobalShortcut(keyCode: 40, modifiers: 256 | 512)
        f.backend.rejected = occupied
        f.controller.beginRecording(.playPause)
        #expect(f.backend.registered.isEmpty)
        #expect(f.controller.assign(occupied, to: .playPause) != nil)
        f.controller.endRecording()
        #expect(f.controller.bindings[.playPause] == chord)
        #expect(Array(f.backend.registered.values) == [chord])
    }

    @Test func successfulCandidateRemainsRegisteredThroughCommit() {
        let f = ShortcutFixture(); defer { f.stop() }
        f.backend.rejectRepeatedRegistration = true
        #expect(f.controller.assign(chord, to: .playPause) == nil)
        #expect(f.controller.errors.isEmpty)
        #expect(f.backend.registered.values.contains(chord))
        #expect(f.backend.attempts[chord] == 1)
    }

    @Test func recordingDisableAndStopReleaseKeysAndIgnoreStaleEvents() throws {
        let f = ShortcutFixture(); defer { f.stop() }
        #expect(f.controller.assign(chord, to: .nextTrack) == nil)
        let id = try #require(f.backend.registered.keys.first)
        f.backend.onEvent?(id, true)
        f.backend.onEvent?(id, true)
        #expect(f.actions == [.nextTrack]) // held keys do not repeat commands
        f.backend.onEvent?(id, false)
        f.backend.onEvent?(id, true)
        #expect(f.actions.count == 2)
        f.controller.beginRecording(.playPause)
        f.backend.onEvent?(id, true)
        #expect(f.actions.count == 2)
        #expect(f.backend.registered.isEmpty)
        f.controller.endRecording()
        f.backend.onEvent?(id, true) // an old queued event must not fire
        #expect(f.actions.count == 2)
        #expect(f.backend.registered.count == 1)
        f.controller.setEnabled(false)
        #expect(f.backend.registered.isEmpty)
        #expect(f.controller.bindings[.nextTrack] == chord)
        f.controller.setEnabled(true)
        #expect(f.backend.registered.count == 1)
        f.controller.stop()
        #expect(f.backend.registered.isEmpty)
        #expect(f.backend.onEvent == nil)
    }

    @Test func externalResetClearsRegistrations() {
        let f = ShortcutFixture(); defer { f.stop() }
        _ = f.controller.assign(chord, to: .playPause)
        f.defaults.removeObject(forKey: GlobalShortcutsController.bindingsKey)
        f.controller.reloadPreferences()
        #expect(f.controller.bindings.isEmpty)
        #expect(f.backend.registered.isEmpty)
    }

    @Test func invalidKeysAndCorruptPreferencesAreIgnored() {
        let f = ShortcutFixture(); defer { f.stop() }
        #expect(f.controller.assign(.init(keyCode: 0, modifiers: 0), to: .playPause) != nil)
        #expect(f.controller.assign(.init(keyCode: 0, modifiers: 2048), to: .playPause) != nil)
        #expect(f.controller.assign(.init(keyCode: 55, modifiers: 256), to: .playPause) != nil)
        #expect(f.controller.assign(.init(keyCode: 500, modifiers: 256), to: .playPause) != nil)
        #expect(f.controller.assign(.init(keyCode: 0, modifiers: UInt32.max), to: .playPause) != nil)
        f.defaults.set(Data("broken".utf8), forKey: GlobalShortcutsController.bindingsKey)
        f.controller.reloadPreferences()
        #expect(f.backend.registered.isEmpty)
    }

    @Test func nativeRegistrationIsExclusiveAndStopReleasesIt() throws {
        let first = CarbonShortcutBackend()
        let second = CarbonShortcutBackend()
        defer { first.stop(); second.stop() }
        let uncommon = GlobalShortcut(keyCode: 80, modifiers: 256 | 512 | 2048 | 4096)
        try first.register(uncommon, id: 1)
        #expect(throws: ShortcutRegistrationError.self) { try second.register(uncommon, id: 2) }
        first.stop()
        try second.register(uncommon, id: 3)
    }

    @Test func nativeRegistrationRejectsSystemCommands() {
        let backend = CarbonShortcutBackend()
        defer { backend.stop() }
        #expect(throws: ShortcutRegistrationError.self) {
            try backend.register(GlobalShortcut(keyCode: 12, modifiers: 256), id: 1)
        }
    }

    @Test func startupConflictIsVisibleAndCanBeRetried() {
        let f = ShortcutFixture(); defer { f.stop() }
        _ = f.controller.assign(chord, to: .playPause)
        f.controller.stop()
        f.backend.rejected = chord
        f.controller.start()
        #expect(f.controller.errors[.playPause] != nil)
        #expect(f.controller.bindings[.playPause] == chord)
        f.backend.rejected = nil
        f.controller.retryRegistration()
        #expect(f.controller.errors.isEmpty)
        #expect(f.backend.registered.count == 1)
    }
}

@MainActor
private final class FakeShortcutBackend: ShortcutRegistering {
    var onEvent: ((UInt32, Bool) -> Void)?
    var registered: [UInt32: GlobalShortcut] = [:]
    var rejected: GlobalShortcut?
    var rejectRepeatedRegistration = false
    var attempts: [GlobalShortcut: Int] = [:]
    func register(_ shortcut: GlobalShortcut, id: UInt32) throws {
        attempts[shortcut, default: 0] += 1
        if shortcut == rejected || (rejectRepeatedRegistration && attempts[shortcut, default: 0] > 1) {
            throw ShortcutRegistrationError.unavailable
        }
        registered[id] = shortcut
    }
    func unregisterAll() { registered.removeAll() }
    func stop() { unregisterAll(); onEvent = nil }
}

@MainActor
private final class ShortcutFixture {
    let suite = "TrackPeek-shortcuts-\(UUID())"
    let defaults: UserDefaults
    let backend = FakeShortcutBackend()
    var actions: [ShortcutAction] = []
    lazy var controller = GlobalShortcutsController(defaults: defaults, backend: backend, perform: { [weak self] in self?.actions.append($0) })
    init() {
        defaults = UserDefaults(suiteName: suite)!
        controller.start()
    }
    func stop() {
        controller.stop()
        defaults.removePersistentDomain(forName: suite)
    }
}
