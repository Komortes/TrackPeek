import SwiftUI

/// Settings scenes can keep the tall preference-panel toolbar even when the
/// scene requests a compact style. Configure only this view's owning window.
struct SettingsWindowToolbar: NSViewRepresentable {
    func makeNSView(context: Context) -> ToolbarView { ToolbarView() }

    func updateNSView(_ view: ToolbarView, context: Context) {
        view.configureWindow()
    }

    final class ToolbarView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWindow()
        }

        func configureWindow() {
            guard let window, window.toolbarStyle != .unifiedCompact else { return }
            window.toolbarStyle = .unifiedCompact
        }
    }
}

/// Shared building blocks for the Settings window, kept in one place so every
/// page renders with the same spacing and materials.

struct SettingsPage<Navigation: View, Content: View>: View {
    let title: String
    var subtitle: String = ""
    var scrollIdentity: String = ""
    @ViewBuilder var navigation: () -> Navigation
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSectionHeader(title: title, subtitle: subtitle, titleFont: .system(size: 24, weight: .semibold))
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                navigation()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .id(scrollIdentity)
        }
    }
}

extension SettingsPage where Navigation == EmptyView {
    init(title: String, subtitle: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.navigation = { EmptyView() }
        self.content = content
    }
}

struct SettingsSectionHeader: View {
    let title: String
    var subtitle: String = ""
    var titleFont: Font = .headline
    var symbolName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let symbolName {
                HStack(spacing: 6) {
                    Image(systemName: symbolName)
                        .foregroundStyle(.secondary)
                    Text(title)
                }
                .font(titleFont)
            } else {
                Text(title)
                    .font(titleFont)
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    var subtitle: String = ""
    var symbolName: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: title, subtitle: subtitle, symbolName: symbolName)
            content()
        }
    }
}

/// Secondary options stay available without taking over the main settings page.
struct SettingsDisclosure<Content: View>: View {
    let title: String
    var subtitle: String = ""
    @ViewBuilder var content: () -> Content
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content().padding(.top, 10)
        } label: {
            SettingsSectionHeader(title: title, subtitle: subtitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
    }
}

struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .toggleStyle(.switch)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var subtitle: String = ""
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            control()
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 14)
    }
}

extension View {
    /// Native pop-up buttons use their intrinsic width inside a SwiftUI frame.
    /// Anchor that button to the row edge instead of centering it in the column.
    func settingsMenuControl(width: CGFloat = 220) -> some View {
        pickerStyle(.menu)
            .labelsHidden()
            .frame(width: width, alignment: .trailing)
    }
}

struct SettingsValueSlider: View {
    let label: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(label)
                .accessibilityValue(text)
                .frame(width: 170)

            Text(text)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)
        }
    }
}


/// Updates immediately when displays are connected, removed or rearranged.
struct DisplayTargetPicker: View {
    @Binding var selection: String
    @State private var displays = ConnectedDisplayChoice.current()

    private var selectedDisplayIsMissing: Bool {
        guard let id = DisplaySelection.persistentID(from: selection) else { return false }
        return !displays.contains { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Picker(String(localized: "Display"), selection: $selection) {
                ForEach(displays) { display in
                    Text(display.title).tag(DisplaySelection.value(for: display.id))
                }
                if selectedDisplayIsMissing {
                    Text(String(localized: "Selected display is disconnected")).tag(selection)
                }
                Divider()
                ForEach(NotchDisplayTarget.allCases) { target in
                    Label(target.title, systemImage: target.symbolName).tag(target.rawValue)
                }
            }
            .settingsMenuControl(width: 300)
            .accessibilityLabel(String(localized: "Player Display"))
            if selectedDisplayIsMissing {
                Text(String(localized: "Using the main display for now. Your selection is saved until it reconnects."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 300, alignment: .trailing)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displays = ConnectedDisplayChoice.current()
        }
    }
}
