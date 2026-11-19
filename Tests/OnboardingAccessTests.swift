import Foundation
import Testing
@testable import TrackPeek

@MainActor
@Suite("First-run player access")
struct OnboardingAccessTests {
    @Test("rechecks once on return from an explicitly opened permission pane")
    func returningFromPermissions() async throws {
        var calls = 0
        let access = OnboardingAccessCheck {
            calls += 1
            return calls == 1 ? .denied : .granted
        }
        #expect(access.returnedToApp(for: .spotify) == nil)
        await access.check().value
        access.openPermissions(for: .spotify) { false }
        #expect(access.returnedToApp(for: .spotify) == nil)
        access.openPermissions(for: .spotify) { true }
        let retry = try #require(access.returnedToApp(for: .spotify))
        await retry.value
        #expect(access.status == .granted)
        #expect(access.returnedToApp(for: .spotify) == nil)
        #expect(calls == 2)
    }

    @Test("a late denial cannot replace the new source's result or a closed window's state", arguments: [true, false])
    func ignoresObsoleteResult(switchSources: Bool) async {
        let (started, didStart) = AsyncStream<Void>.makeStream()
        var finish: CheckedContinuation<Void, Never>?
        var calls = 0
        let access = OnboardingAccessCheck {
            calls += 1
            if calls == 1 {
                await withCheckedContinuation { continuation in
                    finish = continuation
                    didStart.yield()
                    didStart.finish()
                }
                return .denied
            }
            return .granted
        }

        let oldCheck = access.check()
        for await _ in started { break }
        access.reset()
        if switchSources { await access.check().value }
        finish?.resume()
        await oldCheck.value
        #expect(access.status == (switchSources ? .granted : .unknown))
    }

    @Test("switching sources while in System Settings cancels the pending recheck")
    func abandonsPermissionTrip() async {
        let access = OnboardingAccessCheck { .denied }
        await access.check().value
        access.openPermissions(for: .spotify) { true }
        access.reset()
        #expect(access.returnedToApp(for: .appleMusic) == nil)
        #expect(access.returnedToApp(for: .spotify) == nil)
        #expect(access.status == .unknown)
    }
}
