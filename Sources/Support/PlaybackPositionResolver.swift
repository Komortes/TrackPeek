import Foundation

enum PlaybackPositionResolver {
    static func livePosition(
        snapshotPosition: TimeInterval,
        snapshotDate: Date,
        now: Date,
        duration: TimeInterval,
        isPlaying: Bool
    ) -> TimeInterval {
        let elapsed = isPlaying ? max(now.timeIntervalSince(snapshotDate), 0) : 0
        return min(max(snapshotPosition + elapsed, 0), max(duration, 0))
    }

    static func position(
        at location: CGFloat,
        width: CGFloat,
        duration: TimeInterval
    ) -> TimeInterval {
        guard width > 0, duration > 0 else {
            return 0
        }

        let fraction = min(max(location / width, 0), 1)
        return duration * fraction
    }
}
