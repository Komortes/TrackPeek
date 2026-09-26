import Foundation

/// Tracks actual analyzer progress rather than the lifetime of an allocated tap.
/// All dates are monotonic uptime; silent but valid buffers count as progress.
struct AudioCaptureHealth {
    enum Phase: Equatable {
        case idle, waitingForAudio, running, stalled
    }

    static let gracePeriod: TimeInterval = 3
    private(set) var phase = Phase.idle
    private(set) var failureCount = 0
    private(set) var retryAfter: TimeInterval = 0
    private var lastSequence: UInt64 = 0
    private var lastProgressAt: TimeInterval?
    private var attemptStartedAt: TimeInterval?

    /// Allocation succeeding does not reset failure backoff; only real data can.
    @discardableResult
    mutating func beginAttempt(at now: TimeInterval) -> Bool {
        guard phase == .idle || phase == .stalled, now >= retryAfter else { return false }
        phase = .waitingForAudio
        attemptStartedAt = now
        lastProgressAt = nil
        lastSequence = 0
        return true
    }

    mutating func observe(sequence: UInt64, at now: TimeInterval) {
        guard let started = attemptStartedAt,
              phase == .waitingForAudio || phase == .running else { return }
        if sequence != lastSequence, sequence > 0 {
            lastSequence = sequence
            lastProgressAt = now
            phase = .running
            failureCount = 0
            retryAfter = 0
        } else if now - (lastProgressAt ?? started) >= Self.gracePeriod {
            failAttempt(at: now)
        }
    }

    mutating func failAttempt(at now: TimeInterval) {
        // A stalled attempt is counted once, regardless of subsequent polls.
        guard attemptStartedAt != nil else { return }
        phase = .stalled
        attemptStartedAt = nil
        lastProgressAt = nil
        failureCount = min(failureCount + 1, 5)
        retryAfter = now + min(pow(2, Double(failureCount)), 30)
    }

    mutating func reset() {
        self = Self()
    }
}
