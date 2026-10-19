import Testing
@testable import TrackPeek

@MainActor
@Suite("Application relaunch")
struct ApplicationRelauncherTests {
    @Test("the replacement can acquire shortcuts before the old app terminates")
    func successfulRelaunch() async throws {
        var events: [String] = []

        try await ApplicationRelauncher.relaunch(
            releaseShortcuts: { events.append("release") },
            launch: {
                #expect(events == ["release"])
                await Task.yield()
                #expect(events == ["release"], "Do not terminate while launch is pending")
                events.append("replacement started")
            },
            restoreShortcuts: { events.append("restore") },
            terminate: { events.append("terminate") }
        )

        #expect(events == ["release", "replacement started", "terminate"])
    }

    @Test("a failed replacement preserves the running app and restores its shortcuts")
    func failedRelaunch() async {
        var events: [String] = []
        var caughtError: LaunchError?

        do {
            try await ApplicationRelauncher.relaunch(
                releaseShortcuts: { events.append("release") },
                launch: {
                    #expect(events == ["release"])
                    events.append("launch failed")
                    throw LaunchError.denied
                },
                restoreShortcuts: { events.append("restore") },
                terminate: { events.append("terminate") }
            )
            Issue.record("A failed launch must be reported to the caller")
        } catch {
            caughtError = error as? LaunchError
        }

        #expect(caughtError == .denied)
        #expect(events == ["release", "launch failed", "restore"])
    }

    private enum LaunchError: Error { case denied }
}
