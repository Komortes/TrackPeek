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
            return "Разрешите запуск TrackPeek в системных настройках входа."
        case .notFound:
            return "macOS не нашла приложение для запуска при входе."
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
                ? "Не удалось включить запуск при входе. Проверьте системные настройки."
                : "Не удалось отключить запуск при входе. Проверьте системные настройки."
        }
        status = readStatus()
    }
}
