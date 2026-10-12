import Testing
@testable import TrackPeek

@Suite("Volume control interaction")
struct VolumeControlStateTests {
    @Test("a completed snapshot restores the actual volume even when the player reports the same number")
    func unchangedSnapshot() {
        var state = VolumeControlState()
        #expect(state.change(to: 51) == 51)
        #expect(state.displayedValue(snapshot: 50) == 51)
        state.snapshotDidChange()
        #expect(state.displayedValue(snapshot: 50) == 50)
    }

    @Test("keyboard and accessibility changes commit without a mouse editing callback")
    func nonMouseChanges() {
        var state = VolumeControlState()
        #expect(state.change(to: 51) == 51)
        #expect(state.change(to: 52) == 52)
        #expect(state.displayedValue(snapshot: 50) == 52)
        state.snapshotDidChange()
        #expect(state.displayedValue(snapshot: 52) == 52)
    }

    @Test("a drag sends only its final value and ignores intervening snapshots")
    func dragCommit() {
        var state = VolumeControlState()
        #expect(state.editingChanged(true) == nil)
        #expect(state.change(to: 60) == nil)
        #expect(state.change(to: 72) == nil)
        state.snapshotDidChange()
        #expect(state.displayedValue(snapshot: 55) == 72)
        #expect(state.editingChanged(false) == 72)
        #expect(state.displayedValue(snapshot: 71) == 71)
        #expect(state.editingChanged(false) == nil)
    }

    @Test("untrusted volume values cannot escape the player range")
    func clampsValues() {
        var state = VolumeControlState()
        #expect(state.change(to: -20) == 0)
        #expect(state.change(to: 120) == 100)
        #expect(state.change(to: .nan) == nil)
        #expect(state.displayedValue(snapshot: 50) == 100)
        state.snapshotDidChange()
        #expect(state.displayedValue(snapshot: 500) == 100)
        #expect(state.displayedValue(snapshot: -30) == 0)
    }
}

@Suite("Playback capabilities")
struct PlaybackCapabilitiesTests {
    @Test("spotify exposes seek, volume, shuffle and repeat")
    func spotifyCapabilities() {
        let caps = PlaybackCapabilities.capabilities(for: .spotify)
        #expect(caps.contains(.seek))
        #expect(caps.contains(.volume))
        #expect(caps.contains(.shuffle))
        #expect(caps.contains(.repeatTrack))
    }

    @Test("music exposes only seek and volume — spike showed set shuffle/repeat are unreliable")
    func musicCapabilities() {
        let caps = PlaybackCapabilities.capabilities(for: .appleMusic)
        #expect(caps.contains(.seek))
        #expect(caps.contains(.volume))
        #expect(!caps.contains(.shuffle))
        #expect(!caps.contains(.repeatTrack))
    }

    @Test("repeat mode raw values stay stable")
    func repeatModeRawValues() {
        #expect(RepeatMode(rawValue: "off") == .off)
        #expect(RepeatMode(rawValue: "all") == .all)
        #expect(RepeatMode(rawValue: "one") == .one)
    }
}
