import Testing
@testable import TrackPeek

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
