import SwiftUI

/// Shared building blocks for the Settings window, kept in one place so every
/// tab (General/Notch/Player) renders with the same spacing and materials.

struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSectionHeader(title: title, subtitle: subtitle, titleFont: .title2.weight(.semibold))
                content()
            }
            .padding(24)
        }
    }
}

struct SettingsSectionHeader: View {
    let title: String
    let subtitle: String
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

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    var symbolName: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: title, subtitle: subtitle, symbolName: symbolName)
            content()
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        Divider().padding(.leading, 14)
    }
}

struct SettingsValueSlider: View {
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: value, in: range, step: step)
                .frame(width: 170)

            Text(text)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)
        }
    }
}
