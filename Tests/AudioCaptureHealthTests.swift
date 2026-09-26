import Testing
@testable import TrackPeek

@Suite("Audio capture health")
struct AudioCaptureHealthTests {
    @Test("tap allocation waits for actual analyzed audio before reporting running")
    func startupGrace() {
        var health = AudioCaptureHealth()
        let started = health.beginAttempt(at: 100)
        #expect(started)
        health.observe(sequence: 0, at: 102.9)
        #expect(health.phase == .waitingForAudio)
        #expect(health.failureCount == 0)
        health.observe(sequence: 0, at: 103)
        #expect(health.phase == .stalled)
        #expect(health.retryAfter == 105)
    }

    @Test("valid buffers remain healthy even when their audio levels are all zero")
    func silenceIsProgress() {
        var health = AudioCaptureHealth()
        health.beginAttempt(at: 0)
        for second in 1 ... 120 {
            // The counter measures analyzed buffers, independent of their amplitude.
            health.observe(sequence: UInt64(second), at: Double(second))
            #expect(health.phase == .running)
        }
        #expect(health.failureCount == 0)
    }

    @Test("a stream that stops delivering valid buffers stalls after its last progress")
    func stallsAfterRunning() {
        var health = AudioCaptureHealth()
        health.beginAttempt(at: 10)
        health.observe(sequence: 45, at: 11)
        health.observe(sequence: 45, at: 13.9)
        #expect(health.phase == .running)
        health.observe(sequence: 45, at: 14)
        #expect(health.phase == .stalled)
        #expect(health.retryAfter == 16)
        health.observe(sequence: 45, at: 100)
        health.failAttempt(at: 100)
        #expect(health.failureCount == 1)
        #expect(health.retryAfter == 16)
    }

    @Test("successful allocations without data retain bounded retry backoff")
    func allocationIsNotRecovery() {
        var health = AudioCaptureHealth()
        var now = 0.0
        for delay in [2.0, 4, 8, 16, 30, 30, 30] {
            let started = health.beginAttempt(at: now)
            #expect(started)
            let overlappingAttempt = health.beginAttempt(at: now + 0.1)
            #expect(!overlappingAttempt)
            health.observe(sequence: 0, at: now + 3)
            #expect(health.phase == .stalled)
            #expect(health.retryAfter == now + 3 + delay)
            let prematureRetry = health.beginAttempt(at: health.retryAfter - 0.001)
            #expect(!prematureRetry)
            now = health.retryAfter
        }
        #expect(health.failureCount == 5)
    }

    @Test("capture errors use the same backoff and only subsequent progress resets it")
    func errorsAndRecovery() {
        var health = AudioCaptureHealth()
        health.beginAttempt(at: 0)
        health.failAttempt(at: 0)
        #expect(health.retryAfter == 2)
        let secondAttempt = health.beginAttempt(at: 2)
        #expect(secondAttempt)
        health.failAttempt(at: 2)
        #expect(health.retryAfter == 6)
        let thirdAttempt = health.beginAttempt(at: 6)
        #expect(thirdAttempt)
        #expect(health.failureCount == 2)
        health.observe(sequence: 1, at: 6.1)
        #expect(health.phase == .running)
        #expect(health.failureCount == 0)
        health.observe(sequence: 1, at: 9.2)
        #expect(health.retryAfter == 11.2)
    }

    @Test("source change or stop clears stale data and any delayed retry")
    func reset() {
        var health = AudioCaptureHealth()
        health.beginAttempt(at: 50)
        health.observe(sequence: 123, at: 51)
        health.failAttempt(at: 52)
        health.reset()
        #expect(health.phase == .idle)
        #expect(health.failureCount == 0)
        #expect(health.retryAfter == 0)
        let newAttempt = health.beginAttempt(at: 53)
        #expect(newAttempt)
        health.observe(sequence: 0, at: 54)
        #expect(health.phase == .waitingForAudio)
        health.observe(sequence: 1, at: 54.1)
        #expect(health.phase == .running)
    }
}
