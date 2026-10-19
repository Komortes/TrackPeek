import Foundation
import ServiceManagement
import Observation

@Observable
@MainActor
final class LaunchAtLogin {
    private(set) var status: SMAppService.Status
    private(set) var errorMessage: String?
    @ObservationIgnored private let readStatus: () -> SMAppService.Status
    @ObservationIgnored private let register: () throws -> Void
    @ObservationIgnored private let unregister: () throws -> Void

    init(
        readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }
    ) {
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        status = readStatus()
    }

    /// An approved or pending registration expresses the user's saved intent.
    var isEnabled: Bool { status == .enabled || status == .requiresApproval }

    var message: String? {
        if let errorMessage { return errorMessage }
        switch status {
        case .requiresApproval:
            return String(localized: "Allow TrackPeek to open at login in System Settings.")
        case .notFound:
            return String(localized: "macOS could not find the app to open at login.")
        default:
            return nil
        }
    }

    var showsSystemSettings: Bool { message != nil }

    func refresh() {
        status = readStatus()
        errorMessage = nil
    }

    func setEnabled(_ enabled: Bool) {
        refresh()
        do {
            if enabled {
                if !isEnabled { try register() }
            } else if status != .notRegistered {
                try unregister()
            }
        } catch {
            errorMessage = enabled
                ? String(localized: "Could not enable Open at Login. Check System Settings.")
                : String(localized: "Could not disable Open at Login. Check System Settings.")
        }
        status = readStatus()
    }
}
