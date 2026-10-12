import Foundation

enum PlaybackPositionResolver {
    static func seekPosition(
        from position: TimeInterval,
        by offset: TimeInterval,
        duration: TimeInterval
    ) -> TimeInterval? {
        guard position.isFinite, offset.isFinite, duration.isFinite, duration > 0 else { return nil }
        return min(max(position + offset, 0), duration)
    }

    static func livePosition(
        snapshotPosition: TimeInterval,
        snapshotDate: Date,
        now: Date,
        duration: TimeInterval,
        isPlaying: Bool
    ) -> TimeInterval {
        guard duration.isFinite, duration > 0 else { return 0 }
        let interval = now.timeIntervalSince(snapshotDate)
        let elapsed = isPlaying && interval.isFinite ? max(interval, 0) : 0
        let position = snapshotPosition.isFinite ? max(snapshotPosition, 0) : 0
        return min(position + elapsed, duration)
    }

    /// Сглаживает рассинхрон между интерполируемой позицией и свежим значением
    /// из AppleScript: небольшие расхождения (задержка самого скрипта) не должны
    /// дёргать таймлайн, крупные (внешний seek, смена трека) — принимаются сразу.
    static func reconciledPosition(
        fetched: TimeInterval,
        predicted: TimeInterval,
        isSeekSettling: Bool,
        tolerance: TimeInterval = 1.5
    ) -> TimeInterval {
        if isSeekSettling {
            return predicted
        }

        return abs(fetched - predicted) <= tolerance ? predicted : fetched
    }

    static func position(
        at location: CGFloat,
        width: CGFloat,
        duration: TimeInterval
    ) -> TimeInterval {
        guard location.isFinite, width.isFinite, duration.isFinite,
              width > 0, duration > 0 else {
            return 0
        }

        let fraction = min(max(location / width, 0), 1)
        return duration * fraction
    }
}
