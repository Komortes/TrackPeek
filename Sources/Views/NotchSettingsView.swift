import Foundation
import SwiftUI

struct NotchSettingsView: View {
    private enum Page: String, CaseIterable {
        case appearance, behavior

        var title: String {
            switch self {
            case .appearance: String(localized: "Appearance")
            case .behavior: String(localized: "Behavior")
            }
        }
    }

    @State private var selectedPage = Page.appearance

    @AppStorage(NotchContentLayout.storageKey) private var contentLayoutRaw = NotchContentLayout.fallback.rawValue
    @AppStorage(OverlayMode.storageKey)
    private var selectedModeRawValue = OverlayMode.fallback.rawValue
    @AppStorage(NotchPreferences.displayTargetKey)
    private var displayTargetRawValue = NotchDisplayTarget.fallback.rawValue
    @AppStorage(NotchPreferences.widthKey)
    private var width = NotchPreferences.widthFallback
    @AppStorage(NotchPreferences.heightAdjustmentKey)
    private var heightAdjustment = NotchPreferences.heightAdjustmentFallback
    @AppStorage(NotchPreferences.hapticFeedbackKey)
    private var hapticFeedback = NotchPreferences.hapticFeedbackFallback
    @AppStorage(NotchPreferences.songInfoVisibilityKey)
    private var songInfoVisibilityRawValue = NotchSongInfoVisibility.fallback.rawValue
    @AppStorage(NotchPreferences.hoverEnabledKey)
    private var hoverEnabled = NotchPreferences.hoverEnabledFallback
    @AppStorage(NotchPreferences.clickEnabledKey)
    private var clickEnabled = NotchPreferences.clickEnabledFallback
    @AppStorage(NotchPreferences.hoverDelayKey)
    private var hoverDelay = NotchPreferences.hoverDelayFallback
    @AppStorage(NotchPreferences.notificationsEnabledKey)
    private var notificationsEnabled = NotchPreferences.notificationsEnabledFallback
    @AppStorage(NotchPreferences.notificationDurationKey)
    private var notificationDuration = NotchPreferences.notificationDurationFallback
    @AppStorage(NotchPreferences.coloredProgressKey)
    private var coloredProgress = NotchPreferences.coloredProgressFallback
    @AppStorage(NotchPreferences.coloredWaveformKey)
    private var coloredWaveform = NotchPreferences.coloredWaveformFallback
    @AppStorage(NotchPreferences.equalizerSensitivityKey)
    private var equalizerSensitivity = NotchPreferences.equalizerSensitivityFallback
    @AppStorage(NotchPreferences.outlineShimmerKey)
    private var outlineShimmer = NotchPreferences.outlineShimmerFallback
    @AppStorage(NotchPreferences.outlineWidthKey)
    private var outlineWidth = NotchPreferences.outlineWidthFallback
    @AppStorage(NotchPreferences.pulseModeKey)
    private var pulseModeRawValue = NotchPulseMode.fallback.rawValue
    @AppStorage(NotchPreferences.colorSourceKey)
    private var colorSourceRawValue = NotchColorSource.fallback.rawValue
    @AppStorage(NotchPreferences.cornerRadiusKey)
    private var cornerRadius = NotchPreferences.cornerRadiusFallback

    private var selectedMode: OverlayMode {
        OverlayMode(rawValue: selectedModeRawValue) ?? .fallback
    }


    private var songInfoVisibility: Binding<NotchSongInfoVisibility> {
        Binding(
            get: {
                NotchSongInfoVisibility(rawValue: songInfoVisibilityRawValue) ?? .fallback
            },
            set: { songInfoVisibilityRawValue = $0.rawValue }
        )
    }

    private var notchWidth: Binding<Double> {
        Binding(
            get: { NotchPreferences.clampedWidth(width) },
            set: { width = NotchPreferences.clampedWidth($0) }
        )
    }

    private var notchHeightAdjustment: Binding<Double> {
        Binding(
            get: { NotchPreferences.clampedHeightAdjustment(heightAdjustment) },
            set: { heightAdjustment = NotchPreferences.clampedHeightAdjustment($0) }
        )
    }

    private var notchHoverDelay: Binding<Double> {
        Binding(
            get: { NotchPreferences.clampedHoverDelay(hoverDelay) },
            set: { hoverDelay = NotchPreferences.clampedHoverDelay($0) }
        )
    }

    private var notchNotificationDuration: Binding<Double> {
        Binding(
            get: { NotchPreferences.clampedNotificationDuration(notificationDuration) },
            set: {
                notificationDuration = NotchPreferences.clampedNotificationDuration($0)
            }
        )
    }

    private var notchCornerRadius: Binding<Double> {
        Binding(
            get: { NotchPreferences.clampedCornerRadius(cornerRadius) },
            set: { cornerRadius = NotchPreferences.clampedCornerRadius($0) }
        )
    }

    private var notchOutlineWidth: Binding<Double> {
        Binding(
            get: { NotchPreferences.clampedOutlineWidth(outlineWidth) },
            set: { outlineWidth = NotchPreferences.clampedOutlineWidth($0) }
        )
    }

    private var pulseMode: Binding<NotchPulseMode> {
        Binding(
            get: { NotchPulseMode(rawValue: pulseModeRawValue) ?? .fallback },
            set: { pulseModeRawValue = $0.rawValue }
        )
    }

    private var notchEqualizerSensitivity: Binding<Double> {
        Binding(
            get: { NotchPreferences.clampedEqualizerSensitivity(equalizerSensitivity) },
            set: {
                equalizerSensitivity = NotchPreferences.clampedEqualizerSensitivity($0)
            }
        )
    }

    private var colorSource: Binding<NotchColorSource> {
        Binding(
            get: { NotchColorSource(rawValue: colorSourceRawValue) ?? .fallback },
            set: { colorSourceRawValue = $0.rawValue }
        )
    }

    var body: some View {
        SettingsPage(title: String(localized: "Notch"), subtitle: String(localized: "A player at the top of the screen.")) {
            VStack(alignment: .leading, spacing: 12) {
                Picker(String(localized: "Notch Settings"), selection: $selectedPage) {
                    ForEach(Page.allCases, id: \.self) { page in
                        Text(page.title).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                activationStatus
            }

            switch selectedPage {
            case .appearance:
                layoutSection
                sizeSection
                if !isFocusLayout {
                    contentSection
                    equalizerSection
                    effectsSection
                }
            case .behavior:
                displaySection
                interactionSection
                notificationSection
            }
        }
    }

    private var isFocusLayout: Bool {
        contentLayoutRaw == NotchContentLayout.focus.rawValue
    }

    private var layoutSection: some View {
        SettingsSection(title: String(localized: "Content")) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(NotchContentLayout.allCases) { layout in
                    layoutChoice(layout)
                }
            }

            if isFocusLayout {
                Text(String(localized: "Focus hides artwork, the equalizer, lyrics and effects. Your Full Player settings are saved."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func layoutChoice(_ layout: NotchContentLayout) -> some View {
        let isSelected = (NotchContentLayout(rawValue: contentLayoutRaw) ?? .fallback) == layout
        return Button {
            contentLayoutRaw = layout.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                SettingsPlayerPreview(surface: .notch(layout))
                    .frame(height: 132)
                HStack {
                    Text(layout.title).font(.headline)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .opacity(isSelected ? 1 : 0)
                }
                Text(layout.summary)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(isSelected ? 0.05 : 0.02),
                in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(layout.title)
        .accessibilityValue(layout.summary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(layout.summary)
    }

    private var isPanelModeActive: Bool {
        selectedMode == .notch
    }

    private var activationTitle: String {
        switch selectedMode {
        case .notch: String(localized: "Notch is enabled")
        case .floatingWidget: String(localized: "Widget is currently enabled")
        case .off: String(localized: "On-screen player is off")
        }
    }

    private var activationStatus: some View {
        HStack(spacing: 8) {
            Label {
                Text(activationTitle)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: isPanelModeActive ? "checkmark.circle.fill" : "macbook")
                    .foregroundStyle(isPanelModeActive ? Color.green : Color.secondary)
            }
            .font(.callout)

            Spacer()

            if !isPanelModeActive {
                Button(String(localized: "Enable Notch")) {
                    selectedModeRawValue = OverlayMode.notch.rawValue
                }
                .controlSize(.small)
            }
        }
    }

    private var displaySection: some View {
        SettingsSection(title: String(localized: "Placement")) {
            SettingsGroup {
                SettingsRow(title: String(localized: "Display")) {
                    DisplayTargetPicker(selection: $displayTargetRawValue)
                }
            }
        }
    }

    private var interactionSection: some View {
        SettingsSection(title: String(localized: "Expansion")) {
            SettingsGroup {
                SettingsRow(
                    title: String(localized: "On Hover"),
                    subtitle: String(localized: "Open the player under the pointer.")
                ) {
                    Toggle(String(localized: "On Hover"), isOn: $hoverEnabled)
                        .labelsHidden()
                }

                if hoverEnabled {
                    SettingsRowDivider()

                    SettingsRow(
                        title: String(localized: "Hover Delay"),
                        subtitle: String(localized: "Delay before expanding.")
                    ) {
                        SettingsValueSlider(
                            label: String(localized: "Hover Delay"),
                            value: notchHoverDelay,
                            range: NotchPreferences.hoverDelayRange,
                            step: NotchPreferences.hoverDelayStep,
                            text: String(format: String(localized: "%.2f s"), locale: Locale.current, NotchPreferences.clampedHoverDelay(hoverDelay))
                        )
                    }
                }

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "On Click"),
                    subtitle: String(localized: "Keep the player open after clicking.")
                ) {
                    Toggle(String(localized: "On Click"), isOn: $clickEnabled)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(title: String(localized: "Haptic Feedback"), subtitle: String(localized: "When the panel expands.")) {
                    Toggle(String(localized: "Haptic Feedback"), isOn: $hapticFeedback)
                        .labelsHidden()
                }
            }
        }
    }

    private var notificationSection: some View {
        SettingsSection(title: String(localized: "Track Changes")) {
            SettingsGroup {
                SettingsRow(
                    title: String(localized: "Show New Track"),
                    subtitle: String(localized: "Briefly expand the notch.")
                ) {
                    Toggle(String(localized: "Show New Track"), isOn: $notificationsEnabled)
                        .labelsHidden()
                }

                if notificationsEnabled {
                    SettingsRowDivider()

                    SettingsRow(
                        title: String(localized: "Duration")
                    ) {
                        SettingsValueSlider(
                            label: String(localized: "Duration"),
                            value: notchNotificationDuration,
                            range: NotchPreferences.notificationDurationRange,
                            step: NotchPreferences.notificationDurationStep,
                            text: String(
                                format: String(localized: "%.2f s"),
                                locale: Locale.current,
                                NotchPreferences.clampedNotificationDuration(notificationDuration)
                            )
                        )
                    }
                }
            }
        }
    }

    private var sizeSection: some View {
        SettingsSection(title: String(localized: "Size and Shape")) {
            notchSizePreview

            SettingsGroup {
                SettingsRow(
                    title: String(localized: "Width"),
                    subtitle: String(localized: "When collapsed.")
                ) {
                    SettingsValueSlider(
                        label: String(localized: "Width"),
                        value: notchWidth,
                        range: NotchPreferences.widthRange,
                        step: NotchPreferences.widthStep,
                        text: String(localized: "\(Int(NotchPreferences.clampedWidth(width))) px")
                    )
                }

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Height Adjustment"),
                    subtitle: String(localized: "Adjust the fit at the top of the screen.")
                ) {
                    SettingsValueSlider(
                        label: String(localized: "Height Adjustment"),
                        value: notchHeightAdjustment,
                        range: NotchPreferences.heightAdjustmentRange,
                        step: NotchPreferences.heightAdjustmentStep,
                        text: String(
                            format: String(localized: "%+.0f px"),
                            locale: Locale.current,
                            NotchPreferences.clampedHeightAdjustment(heightAdjustment)
                        )
                    )
                }

                if !isFocusLayout {
                    SettingsRowDivider()

                    SettingsRow(title: String(localized: "Corner Radius")) {
                        SettingsValueSlider(
                            label: String(localized: "Corner Radius"),
                            value: notchCornerRadius,
                            range: NotchPreferences.cornerRadiusRange,
                            step: NotchPreferences.cornerRadiusStep,
                            text: String(localized: "\(Int(NotchPreferences.clampedCornerRadius(cornerRadius))) px")
                        )
                    }
                }
            }
        }
    }

    private var contentSection: some View {
        SettingsSection(title: String(localized: "Title and Color")) {
            SettingsGroup {
                SettingsRow(title: String(localized: "Title When Collapsed")) {
                    Picker(String(localized: "Title"), selection: songInfoVisibility) {
                        ForEach(NotchSongInfoVisibility.allCases) { visibility in
                            Text(visibility.title).tag(visibility)
                        }
                    }
                    .settingsMenuControl()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Colored Progress")
                ) {
                    Toggle(String(localized: "Colored Progress"), isOn: $coloredProgress)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Color Source")
                ) {
                    Picker(String(localized: "Color Source"), selection: colorSource) {
                        ForEach(NotchColorSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .settingsMenuControl()
                }
            }
        }
    }

    private var equalizerSection: some View {
        SettingsSection(title: String(localized: "Equalizer")) {
            SettingsGroup {
                SettingsRow(title: String(localized: "Colored Waveform"), subtitle: String(localized: "Use the selected palette.")) {
                    Toggle(String(localized: "Colored Waveform"), isOn: $coloredWaveform)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(title: String(localized: "Sensitivity"), subtitle: String(localized: "How strongly the waveform responds to sound.")) {
                    SettingsValueSlider(
                        label: String(localized: "Equalizer Sensitivity"),
                        value: notchEqualizerSensitivity,
                        range: NotchPreferences.equalizerSensitivityRange,
                        step: NotchPreferences.equalizerSensitivityStep,
                        text: String(
                            format: String(localized: "%.1f×"),
                            locale: Locale.current,
                            NotchPreferences.clampedEqualizerSensitivity(equalizerSensitivity)
                        )
                    )
                }
            }
        }
    }

    private var effectsSection: some View {
        SettingsDisclosure(title: String(localized: "Visual Effects"), subtitle: String(localized: "Outline and Pulse")) {
            SettingsGroup {
                SettingsRow(
                    title: String(localized: "Shimmering Outline"),
                    subtitle: String(localized: "Colors shift smoothly around the panel edges.")
                ) {
                    Toggle(String(localized: "Shimmering Outline"), isOn: $outlineShimmer)
                        .labelsHidden()
                }

                if outlineShimmer {
                    SettingsRowDivider()

                    SettingsRow(
                        title: String(localized: "Outline Width")
                    ) {
                        SettingsValueSlider(
                            label: String(localized: "Outline Width"),
                            value: notchOutlineWidth,
                            range: NotchPreferences.outlineWidthRange,
                            step: NotchPreferences.outlineWidthStep,
                            text: String(
                                format: String(localized: "%.1f px"),
                                locale: Locale.current,
                                NotchPreferences.clampedOutlineWidth(outlineWidth)
                            )
                        )
                    }
                }

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Pulse"),
                    subtitle: String(localized: "Responds to audio volume.")
                ) {
                    Picker(String(localized: "Pulse"), selection: pulseMode) {
                        ForEach(NotchPulseMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .settingsMenuControl()
                }
            }
        }
    }

    private var notchSizePreview: some View {
        let compact = NotchPreferences.compactSize(
            width: NotchPreferences.clampedWidth(width),
            heightAdjustment: NotchPreferences.clampedHeightAdjustment(heightAdjustment)
        )
        let scale = 0.6
        let previewWidth = compact.width * scale
        let previewHeight = max(16, compact.height * scale + 6)
        let previewRadius = NotchPreferences.clampedCornerRadius(cornerRadius) * scale

        return VStack(spacing: 4) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 40)

                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: previewRadius,
                    bottomTrailingRadius: previewRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color.black)
                .frame(width: previewWidth, height: previewHeight)
                .animation(.easeInOut(duration: 0.18), value: previewWidth)
                .animation(.easeInOut(duration: 0.18), value: previewHeight)
                .animation(.easeInOut(duration: 0.18), value: previewRadius)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(String(localized: "Collapsed Panel"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}
