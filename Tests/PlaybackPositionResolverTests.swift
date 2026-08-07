import Foundation
import Testing
@testable import TrackPeek

@Suite("Playback position resolver")
struct PlaybackPositionResolverTests {
    @Test("advances a playing snapshot and clamps it to duration")
    func advancesPlayingSnapshot() {
        let snapshotDate = Date(timeIntervalSince1970: 100)

        #expect(
            PlaybackPositionResolver.livePosition(
                snapshotPosition: 40,
                snapshotDate: snapshotDate,
                now: Date(timeIntervalSince1970: 102.5),
                duration: 180,
                isPlaying: true
            ) == 42.5
        )
        #expect(
            PlaybackPositionResolver.livePosition(
                snapshotPosition: 179,
                snapshotDate: snapshotDate,
                now: Date(timeIntervalSince1970: 105),
                duration: 180,
                isPlaying: true
            ) == 180
        )
    }

    @Test("keeps a paused snapshot still")
    func keepsPausedSnapshotStill() {
        #expect(
            PlaybackPositionResolver.livePosition(
                snapshotPosition: 40,
                snapshotDate: Date(timeIntervalSince1970: 100),
                now: Date(timeIntervalSince1970: 120),
                duration: 180,
                isPlaying: false
            ) == 40
        )
    }

    @Test("keeps the predicted position when the fetched one drifts slightly")
    func smoothsSmallDrift() {
        #expect(
            PlaybackPositionResolver.reconciledPosition(
                fetched: 41.2,
                predicted: 42.5,
                isSeekSettling: false
            ) == 42.5
        )
    }

    @Test("accepts the fetched position on large drift (external seek)")
    func acceptsLargeDrift() {
        #expect(
            PlaybackPositionResolver.reconciledPosition(
                fetched: 90,
                predicted: 42.5,
                isSeekSettling: false
            ) == 90
        )
    }

    @Test("ignores stale fetched positions while a seek settles")
    func ignoresStaleFetchWhileSeekSettles() {
        #expect(
            PlaybackPositionResolver.reconciledPosition(
                fetched: 10,
                predicted: 95,
                isSeekSettling: true
            ) == 95
        )
    }

    @Test("maps pointer location to a clamped playback position")
    func mapsPointerLocation() {
        #expect(PlaybackPositionResolver.position(at: -10, width: 100, duration: 200) == 0)
        #expect(PlaybackPositionResolver.position(at: 50, width: 100, duration: 200) == 100)
        #expect(PlaybackPositionResolver.position(at: 120, width: 100, duration: 200) == 200)
    }
}
