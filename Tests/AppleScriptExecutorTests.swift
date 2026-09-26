import AppKit
import Darwin
import Testing
@testable import TrackPeek

@Suite("Isolated AppleScript execution", .serialized)
struct AppleScriptExecutorTests {
    @Test("a timed-out native script cannot block the next command")
    func recoversAfterNativeTimeout() async throws {
        try await withExecutor { executor in
            // Warm up before measuring cancellation and process replacement.
            _ = try await executor.run("return 1")
            do {
                _ = try await executor.run("delay 2\nreturn 99", timeout: .milliseconds(100))
                Issue.record("The delayed script should time out")
            } catch AppleScriptExecutionError.timedOut {
                // The caller's deadline expires before the native delay.
            }

            let started = ContinuousClock.now
            let result = try await executor.run("return 42")
            #expect(result.int32Value == 42)
            #expect(started.duration(to: .now) < .seconds(1))
        }
    }

    @Test("native descriptors preserve Unicode, empty lists and binary data")
    func nativeResultRoundTrip() async throws {
        try await withExecutor { executor in
            let result = try await executor.run(
                "return {\"Привіт, музыка 🎵\", \"\", {}, {true, 42}, «data rdat00FF1020»}"
            )
            #expect(result.numberOfItems == 5)
            #expect(result.atIndex(1)?.stringValue == "Привіт, музыка 🎵")
            #expect(result.atIndex(2)?.stringValue == "")
            let empty = try #require(result.atIndex(3))
            #expect(empty.descriptorType == typeAEList)
            #expect(empty.numberOfItems == 0)
            let nested = try #require(result.atIndex(4))
            #expect(nested.numberOfItems == 2)
            #expect(nested.atIndex(1)?.booleanValue == true)
            #expect(nested.atIndex(2)?.int32Value == 42)
            let binary = try #require(result.atIndex(5))
            #expect(binary.descriptorType == 0x72646174) // 'rdat'
            #expect(binary.data == Data([0x00, 0xFF, 0x10, 0x20]))
        }
    }

    @Test("a Unicode response larger than the pipe buffer arrives intact without replacing the helper")
    func largeResponseRoundTrip() async throws {
        try await withExecutor { executor in
            _ = try await executor.run("return 1")
            let firstPID = try #require(await executor.processIdentifier)
            // A short source produces 128 KiB of Unicode, exercising partial pipe I/O.
            let chunk = String(repeating: "🎵", count: 64)
            let result = try await executor.run("""
                set output to ""
                repeat 512 times
                    set output to output & "\(chunk)"
                end repeat
                return output
                """)
            #expect(result.stringValue == String(repeating: chunk, count: 512))
            #expect(await executor.processIdentifier == firstPID)
            let next = try await executor.run("return 42")
            #expect(next.int32Value == 42)
            #expect(await executor.processIdentifier == firstPID)
        }
    }

    @Test("successful calls reuse one helper until shutdown")
    func reusesHelperProcess() async throws {
        try await withExecutor { executor in
            #expect(await executor.processIdentifier == nil)
            _ = try await executor.run("return 1")
            let firstPID = try #require(await executor.processIdentifier)
            let next = try await executor.run("return 2")
            #expect(next.int32Value == 2)
            #expect(await executor.processIdentifier == firstPID)
            #expect(await executor.pendingRequestCount == 0)
            await executor.shutdown()
            #expect(await executor.processIdentifier == nil)
            #expect(await executor.pendingRequestCount == 0)
        }
    }

    @Test("canceling an active native call replaces its helper without waiting for the script")
    func activeCancellationRecoversPromptly() async throws {
        try await withExecutor { executor in
            _ = try await executor.run("return 1")
            let firstPID = try #require(await executor.processIdentifier)
            let active = command("delay 30\nreturn 99", on: executor)
            defer { active.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 1 }

            let started = ContinuousClock.now
            active.cancel()
            #expect(await active.value == .cancelled)
            let next = try await executor.run("return 42")
            #expect(next.int32Value == 42)
            #expect(started.duration(to: .now) < .seconds(1))
            #expect(await executor.processIdentifier != firstPID)
        }
    }

    @Test("canceling a queued script removes only that script and prevents late execution")
    func queuedCancellationDoesNotRunLater() async throws {
        try await withExecutor { executor in
            _ = try await executor.run("return 1")
            let firstPID = try #require(await executor.processIdentifier)
            let active = command("delay 3\nreturn 10", on: executor)
            defer { active.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 1 }
            let queued = command("delay 3\nreturn 20", on: executor)
            defer { queued.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 2 }

            queued.cancel()
            #expect(await queued.value == .cancelled)
            #expect(await executor.pendingRequestCount == 1)
            #expect(await active.value == .value(10))

            // A canceled delay must not start when the preceding call finishes.
            let started = ContinuousClock.now
            let next = try await executor.run("return 42")
            #expect(next.int32Value == 42)
            #expect(started.duration(to: .now) < .seconds(1))
            #expect(await executor.processIdentifier == firstPID)
        }
    }

    @Test("an active timeout invalidates pending commands instead of replaying them")
    func timeoutInvalidatesQueuedCommands() async throws {
        try await withExecutor { executor in
            _ = try await executor.run("return 1")
            let active = command("delay 30\nreturn 10", on: executor, timeout: .milliseconds(500))
            defer { active.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 1 }
            let queued = command("delay 3\nreturn 20", on: executor)
            defer { queued.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 2 }

            #expect(await active.value == .timedOut)
            #expect(await queued.value == .helperUnavailable)
            #expect(await executor.pendingRequestCount == 0)
            let started = ContinuousClock.now
            let next = try await executor.run("return 42")
            #expect(next.int32Value == 42)
            #expect(started.duration(to: .now) < .seconds(1))
        }
    }

    @Test("a queued timeout removes only the expired call and leaves the active helper running")
    func queuedTimeoutKeepsActiveCall() async throws {
        try await withExecutor { executor in
            _ = try await executor.run("return 1")
            let firstPID = try #require(await executor.processIdentifier)
            let active = command("delay 3\nreturn 10", on: executor)
            defer { active.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 1 }
            let queued = command("delay 3\nreturn 20", on: executor, timeout: .milliseconds(300))
            defer { queued.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 2 }

            #expect(await queued.value == .timedOut)
            #expect(await executor.pendingRequestCount == 1)
            #expect(await executor.processIdentifier == firstPID)
            #expect(await active.value == .value(10))
            let started = ContinuousClock.now
            let next = try await executor.run("return 42")
            #expect(next.int32Value == 42)
            #expect(started.duration(to: .now) < .seconds(1))
            #expect(await executor.processIdentifier == firstPID)
        }
    }

    @Test("a task canceled before submission never starts a helper")
    func preCancelledTaskDoesNotLaunchHelper() async throws {
        try await withExecutor { executor in
            let cancelled = Task { () -> ScriptTestOutcome in
                // Self-cancel before calling run: no scheduling race or timer.
                withUnsafeCurrentTask { $0?.cancel() }
                do {
                    let result = try await executor.run("return 99")
                    return .value(result.int32Value)
                } catch is CancellationError {
                    return .cancelled
                } catch {
                    return .unexpected(String(describing: error))
                }
            }
            #expect(await cancelled.value == .cancelled)
            #expect(await executor.processIdentifier == nil)
            #expect(await executor.pendingRequestCount == 0)
            let next = try await executor.run("return 42")
            #expect(next.int32Value == 42)
        }
    }

    @Test("shutdown completes active and pending callers before a fresh helper can be used")
    func shutdownResolvesPendingCalls() async throws {
        try await withExecutor { executor in
            _ = try await executor.run("return 1")
            let firstPID = try #require(await executor.processIdentifier)
            let active = command("delay 30\nreturn 10", on: executor)
            defer { active.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 1 }
            let queued = command("delay 3\nreturn 20", on: executor)
            defer { queued.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 2 }

            await executor.shutdown()
            #expect(await active.value == .cancelled)
            #expect(await queued.value == .helperUnavailable)
            #expect(await executor.processIdentifier == nil)
            #expect(await executor.pendingRequestCount == 0)
            let started = ContinuousClock.now
            let next = try await executor.run("return 42")
            #expect(next.int32Value == 42)
            #expect(started.duration(to: .now) < .seconds(1))
            #expect(await executor.processIdentifier != firstPID)
        }
    }

    @Test("a crashed helper rejects its pending calls and a fresh command starts a new helper")
    func recoversAfterHelperCrash() async throws {
        try await withExecutor { executor in
            _ = try await executor.run("return 1")
            let firstPID = try #require(await executor.processIdentifier)
            let active = command("delay 30\nreturn 10", on: executor)
            defer { active.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 1 }
            let queued = command("delay 3\nreturn 20", on: executor)
            defer { queued.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 2 }

            // This PID belongs exclusively to this test's independent executor.
            try #require(Darwin.kill(firstPID, SIGKILL) == 0)
            #expect(await active.value == .helperUnavailable)
            #expect(await queued.value == .helperUnavailable)
            let started = ContinuousClock.now
            let next = try await executor.run("return 42")
            #expect(next.int32Value == 42)
            #expect(started.duration(to: .now) < .seconds(1))
            #expect(await executor.processIdentifier != firstPID)
        }
    }

    @Test("the queue admits at most sixteen calls including its active native script")
    func boundsPendingRequests() async throws {
        try await withExecutor { executor in
            _ = try await executor.run("return 1")
            let active = command("delay 30\nreturn 10", on: executor)
            defer { active.cancel() }
            try await waitUntil { await executor.pendingRequestCount == 1 }
            let queued = (1 ... 15).map { value in
                command("return \(value)", on: executor)
            }
            defer { queued.forEach { $0.cancel() } }
            try await waitUntil { await executor.pendingRequestCount == 16 }

            let overflow = command("return 99", on: executor, timeout: .seconds(1))
            #expect(await overflow.value == .busy)
            #expect(await executor.pendingRequestCount == 16)
            active.cancel()
            #expect(await active.value == .cancelled)
            for request in queued {
                #expect(await request.value == .helperUnavailable)
            }
            #expect(await executor.pendingRequestCount == 0)
            let next = try await executor.run("return 42")
            #expect(next.int32Value == 42)
        }
    }

    @Test("script failures preserve the helper and do not poison later calls")
    func scriptFailureDoesNotRestartHelper() async throws {
        try await withExecutor { executor in
            _ = try await executor.run("return 1")
            let firstPID = try #require(await executor.processIdentifier)
            do {
                _ = try await executor.run("error \"deliberate test failure\" number 12345")
                Issue.record("The script's error should reach its caller")
            } catch let AppleScriptExecutionError.scriptFailed(message) {
                #expect(message.contains("deliberate test failure"))
            }
            let next = try await executor.run("return 42")
            #expect(next.int32Value == 42)
            #expect(await executor.processIdentifier == firstPID)
        }
    }

    private func withExecutor(_ body: (AppleScriptExecutor) async throws -> Void) async throws {
        let executor = AppleScriptExecutor()
        do {
            try await body(executor)
            await executor.shutdown()
        } catch {
            await executor.shutdown()
            throw error
        }
    }

    private func command(
        _ source: String,
        on executor: AppleScriptExecutor,
        timeout: Duration = .seconds(10)
    ) -> Task<ScriptTestOutcome, Never> {
        Task {
            do {
                let result = try await executor.run(source, timeout: timeout)
                return .value(result.int32Value)
            } catch is CancellationError {
                return .cancelled
            } catch AppleScriptExecutionError.timedOut {
                return .timedOut
            } catch AppleScriptExecutionError.busy {
                return .busy
            } catch AppleScriptExecutionError.helperUnavailable {
                return .helperUnavailable
            } catch {
                return .unexpected(String(describing: error))
            }
        }
    }

    private func waitUntil(_ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !(await condition()), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(await condition(), "The executor did not reach the expected queue state within two seconds")
    }
}

private enum ScriptTestOutcome: Equatable, Sendable {
    case value(Int32)
    case cancelled
    case timedOut
    case busy
    case helperUnavailable
    case unexpected(String)
}
