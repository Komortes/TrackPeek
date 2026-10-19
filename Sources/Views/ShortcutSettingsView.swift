import SwiftUI
import Carbon

struct ShortcutSettingsView: View {
    private let controller = GlobalShortcutsController.shared
    @State private var assignmentErrors: [ShortcutAction: String] = [:]
    @State private var inputSourceRevision = 0

    var body: some View {
        SettingsPage(title: String(localized: "Keyboard Shortcuts"), subtitle: String(localized: "Control music while working in another app.")) {
            SettingsGroup {
                SettingsRow(title: String(localized: "Global Shortcuts"), subtitle: String(localized: "Your shortcuts stay saved when disabled.")) {
                    Toggle(String(localized: "Global Shortcuts"), isOn: Binding(get: { controller.isEnabled }, set: { controller.setEnabled($0) }))
                        .labelsHidden()
                }
            }
            SettingsSection(title: String(localized: "Actions"), subtitle: String(localized: "Click a field and press a shortcut with ⌘ Command or ⌃ Control.")) {
                SettingsGroup {
                    ForEach(ShortcutAction.allCases) { action in
                        if action != ShortcutAction.allCases.first { SettingsRowDivider() }
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsRow(title: action.title, subtitle: action.subtitle) {
                                HStack(spacing: 6) {
                                    ShortcutRecorder(
                                        title: shortcutTitle(action),
                                        actionTitle: action.title,
                                        isRecording: controller.recordingAction == action,
                                        onBegin: {
                                            assignmentErrors[action] = nil
                                            controller.beginRecording(action)
                                        },
                                        onCancel: { controller.endRecording() },
                                        onKey: { event in handle(event, for: action) }
                                    )
                                    .frame(width: 166, height: 28)
                                    Button {
                                        assignmentErrors[action] = nil
                                        controller.assign(nil, to: action)
                                    } label: { Image(systemName: "xmark.circle") }
                                    .buttonStyle(.borderless)
                                    .disabled(controller.bindings[action] == nil)
                                    .help(String(localized: "Remove Shortcut"))
                                    .accessibilityLabel(String(localized: "Remove shortcut: \(action.title)"))
                                }
                            }
                            if let error = assignmentErrors[action] ?? controller.errors[action] {
                                Label(error, systemImage: "exclamationmark.circle")
                                    .font(.caption).foregroundStyle(.orange)
                                    .padding(.horizontal, 14).padding(.bottom, 10)
                            }
                        }
                    }
                }
                Text(String(localized: "Esc to cancel · Delete to clear. TrackPeek shortcuts are paused while recording."))
                    .font(.caption).foregroundStyle(.secondary)
                if !controller.errors.isEmpty {
                    Button(String(localized: "Reconnect Shortcuts")) { controller.retryRegistration() }
                }
            }
            Text(String(localized: "No shortcuts are assigned by default. Choose unused combinations: shortcuts in other apps cannot always be checked in advance. Panel visibility follows the mode and rules in General settings."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .onDisappear { controller.endRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            controller.endRecording()
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String))) { _ in
            inputSourceRevision += 1
        }
    }

    private func shortcutTitle(_ action: ShortcutAction) -> String {
        _ = inputSourceRevision
        return controller.bindings[action]?.displayName ?? String(localized: "Assign…")
    }

    private func handle(_ event: NSEvent, for action: ShortcutAction) {
        guard controller.recordingAction == action, !event.isARepeat else { return }
        let shortcut = GlobalShortcut(event: event)
        if shortcut.modifiers == 0 {
            if event.keyCode == 53 { controller.endRecording(); return }
            if event.keyCode == 51 || event.keyCode == 117 {
                assignmentErrors[action] = nil
                controller.assign(nil, to: action)
                return
            }
        }
        assignmentErrors[action] = controller.assign(shortcut, to: action)
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let title: String
    let actionTitle: String
    let isRecording: Bool
    let onBegin: () -> Void
    let onCancel: () -> Void
    let onKey: (NSEvent) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.target = button
        button.action = #selector(RecorderButton.begin)
        return button
    }

    func updateNSView(_ button: RecorderButton, context: Context) {
        button.onBegin = onBegin
        button.onCancel = onCancel
        button.onKey = onKey
        button.isRecording = isRecording
        button.title = isRecording ? String(localized: "Press a shortcut…") : title
        button.setAccessibilityLabel("\(actionTitle): \(button.title)")
        button.setAccessibilityHelp(String(localized: "Click to assign a keyboard shortcut. Escape cancels recording."))
    }

    static func dismantleNSView(_ button: RecorderButton, coordinator: ()) {
        if button.isRecording { button.onCancel?() }
        button.onBegin = nil
        button.onCancel = nil
        button.onKey = nil
    }

    final class RecorderButton: NSButton {
        var isRecording = false
        var onBegin: (() -> Void)?
        var onCancel: (() -> Void)?
        var onKey: ((NSEvent) -> Void)?
        override var acceptsFirstResponder: Bool { true }

        @objc func begin() {
            if isRecording { onCancel?(); return }
            guard window?.makeFirstResponder(self) == true else { return }
            // Set synchronously: a key may arrive before the next SwiftUI update.
            isRecording = true
            onBegin?()
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else { super.keyDown(with: event); return }
            if event.keyCode == 48, GlobalShortcut(event: event).modifiers == 0 {
                isRecording = false
                onCancel?()
                window?.selectNextKeyView(self)
                return
            }
            onKey?(event)
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard isRecording, window?.firstResponder === self else {
                return super.performKeyEquivalent(with: event)
            }
            onKey?(event)
            return true
        }

        override func resignFirstResponder() -> Bool {
            if isRecording {
                isRecording = false
                onCancel?()
            }
            return super.resignFirstResponder()
        }
    }
}
