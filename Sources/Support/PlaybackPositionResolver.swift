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
        guard width > 0, duration > 0 else {
            return 0
        }

        let fraction = min(max(location / width, 0), 1)
        return duration * fraction
    }
}
