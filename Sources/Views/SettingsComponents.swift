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

struct SettingsPage<Navigation: View, Accessory: View, Content: View>: View {
    let title: String
    var subtitle: String = ""
    var scrollIdentity: String = ""
    @ViewBuilder var navigation: () -> Navigation
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                pageHeader
                navigation()
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content()
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .id(scrollIdentity)
        }
    }

    private var heading: some View {
        SettingsSectionHeader(title: title, subtitle: subtitle, titleFont: .system(size: 24, weight: .semibold))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var pageHeader: some View {
        if Accessory.self == EmptyView.self {
            heading
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    heading.fixedSize()
                    Spacer(minLength: 0)
                    accessory().fixedSize()
                }
                VStack(alignment: .leading, spacing: 12) {
                    heading
                    accessory()
                }
            }
        }
    }
}

extension SettingsPage where Accessory == EmptyView {
    init(title: String, subtitle: String = "", scrollIdentity: String = "",
         @ViewBuilder navigation: @escaping () -> Navigation,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.scrollIdentity = scrollIdentity
        self.navigation = navigation
        self.accessory = { EmptyView() }
        self.content = content
    }
}

extension SettingsPage where Navigation == EmptyView, Accessory == EmptyView {
    init(title: String, subtitle: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.navigation = { EmptyView() }
        self.accessory = { EmptyView() }
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
        SettingsRowLayout {
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
            // The builder may produce no controls (for example, connected diagnostics).
            HStack(spacing: 8) {
                control()
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }
}

/// Keep a readable label column, moving wide controls below it when needed.
/// One layout preserves the control's identity and keyboard focus on resize.
private struct SettingsRowLayout: Layout {
    private struct Arrangement {
        let size: CGSize
        let label: CGSize
        let control: CGSize
        let stacked: Bool
    }

    private func arrangement(width proposedWidth: CGFloat?, subviews: Subviews) -> Arrangement {
        let control = subviews[1].sizeThatFits(.unspecified)
        let idealLabel = subviews[0].sizeThatFits(.unspecified)
        let idealWidth = idealLabel.width + 16 + control.width
        let width = max(control.width, proposedWidth.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth)
        let stacked = width < min(220, idealLabel.width) + 16 + control.width
        let label = subviews[0].sizeThatFits(
            ProposedViewSize(width: stacked ? width : width - 16 - control.width, height: nil)
        )
        return Arrangement(
            size: CGSize(width: width, height: stacked ? label.height + 10 + control.height : max(label.height, control.height)),
            label: label, control: control, stacked: stacked
        )
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let row = arrangement(width: bounds.width, subviews: subviews)
        let labelY = row.stacked ? bounds.minY : bounds.midY - row.label.height / 2
        let controlOrigin = row.stacked
            ? CGPoint(x: bounds.minX, y: bounds.minY + row.label.height + 10)
            : CGPoint(x: bounds.maxX - row.control.width, y: bounds.midY - row.control.height / 2)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: labelY), anchor: .topLeading,
                          proposal: ProposedViewSize(row.label))
        subviews[1].place(at: controlOrigin, anchor: .topLeading,
                          proposal: ProposedViewSize(row.control))
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
