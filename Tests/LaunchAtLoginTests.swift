import ServiceManagement
import Testing
@testable import TrackPeek

@MainActor
@Suite("Launch at login feedback")
struct LaunchAtLoginTests {
    @Test("failed registration restores actual switch state and gives feedback")
    func failedRegistration() {
        let controller = LaunchAtLogin(readStatus: { .notRegistered }, register: { throw TestError.denied }, unregister: { })
        controller.setEnabled(true)
        #expect(!controller.isEnabled)
        #expect(controller.message != nil)
        #expect(controller.showsSystemSettings)
    }

    @Test("registration requiring approval stays selected and explains the next step")
    func requiresApproval() {
        var status = SMAppService.Status.notRegistered
        let controller = LaunchAtLogin(readStatus: { status }, register: { status = .requiresApproval }, unregister: { status = .notRegistered })
        controller.setEnabled(true)
        #expect(controller.isEnabled)
        #expect(controller.message != nil)
        #expect(controller.showsSystemSettings)
        controller.setEnabled(false)
        #expect(!controller.isEnabled)
        #expect(controller.message == nil)
    }

    @Test("refresh follows external changes without registering again")
    func externalChange() {
        var status = SMAppService.Status.enabled
        var registrations = 0
        let controller = LaunchAtLogin(readStatus: { status }, register: { registrations += 1 }, unregister: { })
        #expect(controller.isEnabled)
        status = .requiresApproval
        controller.refresh()
        controller.setEnabled(true)
        #expect(registrations == 0)
        #expect(controller.showsSystemSettings)
        status = .notRegistered
        controller.refresh()
        #expect(!controller.isEnabled)
    }

    @Test("failed unregistration leaves an enabled service selected")
    func failedUnregistration() {
        let controller = LaunchAtLogin(readStatus: { .enabled }, register: { }, unregister: { throw TestError.denied })
        controller.setEnabled(false)
        #expect(controller.isEnabled)
        #expect(controller.message != nil)
    }

    private enum TestError: Error { case denied }
}
