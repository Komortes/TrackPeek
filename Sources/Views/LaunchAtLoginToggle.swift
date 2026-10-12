import AppKit
import ServiceManagement
import SwiftUI

struct LaunchAtLoginToggle: View {
    @State private var controller = LaunchAtLogin()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                Text("Запускать при входе в систему")
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
                Toggle("Запускать при входе в систему", isOn: Binding(
                    get: { controller.isEnabled },
                    set: { controller.setEnabled($0) }
                ))
                .labelsHidden()
            }

            if let message = controller.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if controller.showsSystemSettings {
                Button("Открыть настройки входа") {
                    SMAppService.openSystemSettingsLoginItems()
                }
                .controlSize(.small)
            }
        }
        .toggleStyle(.switch)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { controller.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            controller.refresh()
        }
    }
}
