import SwiftUI

struct WidgetSettingsView: View {
    private enum Page: String, CaseIterable, Identifiable {
        case template, placement, appearance

        var id: Self { self }

        var title: String {
            switch self {
            case .template: String(localized: "Template")
            case .placement: String(localized: "Placement")
            case .appearance: String(localized: "Appearance")
            }
        }
    }

    @State private var selectedPage = Page.template
    @State private var browsedFamily: NotchWidgetLayoutFamily?

    @AppStorage(OverlayMode.storageKey)
    private var selectedModeRawValue = OverlayMode.fallback.rawValue
    @AppStorage(WidgetPreferences.edgeOnRightKey)
    private var edgeOnRight = true

    @AppStorage(WidgetPreferences.layoutKey)
    private var widgetLayoutRawValue = NotchWidgetLayout.fallback.rawValue
    @AppStorage(WidgetPreferences.positionKey)
    private var widgetPositionRawValue = NotchWidgetPosition.fallback.rawValue
    @AppStorage(WidgetPreferences.freeMoveKey)
    private var freeMoveEnabled = false
    @AppStorage(WidgetPreferences.lyricsEnabledKey)
    private var lyricsEnabled = NotchPreferences.lyricsEnabledFallback
    @AppStorage(WidgetPreferences.widthKey)
    private var width = NotchPreferences.widthFallback
    @AppStorage(WidgetPreferences.displayTargetKey)
    private var displayTargetRawValue = NotchDisplayTarget.mainDisplay.rawValue
    @AppStorage(WidgetPreferences.coloredProgressKey)
    private var coloredProgress = NotchPreferences.coloredProgressFallback
    @AppStorage(WidgetPreferences.coloredWaveformKey)
    private var coloredWaveform = NotchPreferences.coloredWaveformFallback
    @AppStorage(WidgetPreferences.colorSourceKey)
    private var colorSourceRawValue = NotchColorSource.fallback.rawValue
    @AppStorage(WidgetPreferences.equalizerSensitivityKey)
    private var equalizerSensitivity = NotchPreferences.equalizerSensitivityFallback
    @AppStorage(WidgetPreferences.outlineShimmerKey)
    private var outlineShimmer = NotchPreferences.outlineShimmerFallback
    @AppStorage(WidgetPreferences.outlineWidthKey)
    private var outlineWidth = NotchPreferences.outlineWidthFallback
    @AppStorage(WidgetPreferences.pulseModeKey)
    private var pulseModeRawValue = NotchPulseMode.fallback.rawValue
    @AppStorage(WidgetPreferences.glassBackgroundKey)
    private var glassBackground = false
    @AppStorage(WidgetPreferences.alwaysOnTopKey)
    private var alwaysOnTop = true
    @AppStorage(WidgetPreferences.allSpacesKey)
    private var allSpaces = true
    @AppStorage(WidgetPreferences.hideInFullscreenKey)
    private var hideInFullscreen = false
    @AppStorage(WidgetPreferences.positionLockedKey)
    private var positionLocked = false

    private var selectedMode: OverlayMode {
        OverlayMode(rawValue: selectedModeRawValue) ?? .fallback
    }

    private var selectedLayout: NotchWidgetLayout {
        NotchWidgetLayout(rawValue: widgetLayoutRawValue) ?? .fallback
    }

    private var selectedPosition: NotchWidgetPosition {
        NotchWidgetPosition(rawValue: widgetPositionRawValue) ?? .fallback
    }

    private var pulseMode: Binding<NotchPulseMode> {
        Binding(
            get: { NotchPulseMode(rawValue: pulseModeRawValue) ?? .fallback },
            set: { pulseModeRawValue = $0.rawValue }
        )
    }


    private var widgetWidth: Binding<Double> {
        Binding(
            get: { NotchPreferences.clampedWidth(width) },
            set: { width = NotchPreferences.clampedWidth($0) }
        )
    }

    private var colorSource: Binding<NotchColorSource> {
        Binding(
            get: { NotchColorSource(rawValue: colorSourceRawValue) ?? .fallback },
            set: { colorSourceRawValue = $0.rawValue }
        )
    }

    private var widgetSensitivity: Binding<Double> {
        Binding(
            get: { NotchPreferences.clampedEqualizerSensitivity(equalizerSensitivity) },
            set: { equalizerSensitivity = NotchPreferences.clampedEqualizerSensitivity($0) }
        )
    }

    private var widgetOutlineWidth: Binding<Double> {
        Binding(
            get: { NotchPreferences.clampedOutlineWidth(outlineWidth) },
            set: { outlineWidth = NotchPreferences.clampedOutlineWidth($0) }
        )
    }

    private var layoutFamily: Binding<NotchWidgetLayoutFamily> {
        Binding(
            get: { browsedFamily ?? selectedLayout.family },
            set: { browsedFamily = $0 }
        )
    }

    var body: some View {
        SettingsPage(title: String(localized: "Widget"), subtitle: String(localized: "A floating player on your desktop.")) {
            VStack(alignment: .leading, spacing: 12) {
                Picker(String(localized: "Widget Settings"), selection: $selectedPage) {
                    ForEach(Page.allCases) { page in
                        Text(page.title).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                activationStatus
            }

            switch selectedPage {
            case .template:
                layoutSection
            case .placement:
                placementSection
                windowBehaviorSection
            case .appearance:
                appearanceSection
            }
        }
        .onChange(of: widgetLayoutRawValue) { _, _ in
            browsedFamily = selectedLayout.family
        }
    }

    // MARK: Активация

    private var activationStatus: some View {
        HStack(spacing: 8) {
            Label(
                selectedMode == .floatingWidget ? String(localized: "Widget is enabled") : String(localized: "Widget is disabled"),
                systemImage: selectedMode == .floatingWidget ? "checkmark.circle.fill" : "rectangle.on.rectangle"
            )
            .foregroundStyle(.secondary)
            .font(.callout)

            Text("· \(selectedLayout.title)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            if selectedMode != .floatingWidget {
                Button(String(localized: "Enable Widget")) {
                    selectedModeRawValue = OverlayMode.floatingWidget.rawValue
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: Шаблон

    private var layoutSection: some View {
        SettingsSection(title: String(localized: "Templates"), subtitle: String(localized: "Browsing a category does not change the selected template.")) {
            Picker(String(localized: "Template Category"), selection: layoutFamily) {
                ForEach(NotchWidgetLayoutFamily.allCases) { family in
                    Text(family.title).tag(family)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 4) {
                    ForEach((browsedFamily ?? selectedLayout.family).layouts) { layout in
                        layoutChoice(layout)
                    }
                }
                .frame(width: 200)

                VStack(alignment: .leading, spacing: 12) {
                    SettingsPlayerPreview(surface: .widget(selectedLayout))
                        .frame(height: 252)
                        .frame(maxWidth: .infinity)
                        .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedLayout.title).font(.headline)
                        Text(selectedLayout.summary)
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)

                    Text(String(localized: "Preview"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func layoutChoice(_ layout: NotchWidgetLayout) -> some View {
        let isSelected = selectedLayout == layout
        return Button {
            widgetLayoutRawValue = layout.rawValue
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(layout.title).font(.system(size: 13, weight: .semibold))
                    Text(layout.summary)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tint)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(12)
            .background(isSelected ? Color.primary.opacity(0.065) : .clear,
                in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(layout.summary)
        .accessibilityLabel(layout.title)
        .accessibilityValue(layout.summary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Расположение

    private var placementSection: some View {
        SettingsSection(
            title: String(localized: "Location"),
            subtitle: String(localized: "Where the widget appears and whether it can be dragged."),
            symbolName: "arrow.up.and.down.and.arrow.left.and.right"
        ) {
            SettingsGroup {
                SettingsRow(
                    title: String(localized: "Monitor"),
                    subtitle: String(localized: "Where to show the widget.")
                ) {
                    DisplayTargetPicker(selection: $displayTargetRawValue)
                }

                if selectedLayout == .edge {
                    SettingsRowDivider()
                    SettingsRow(title: String(localized: "Screen Edge"), subtitle: String(localized: "Centered on the selected edge, allowing space for the Dock.")) {
                        Picker(String(localized: "Screen Edge"), selection: $edgeOnRight) {
                            Text(String(localized: "Left")).tag(false)
                            Text(String(localized: "Right")).tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }
                } else if !freeMoveEnabled {
                    SettingsRowDivider()
                    SettingsRow(title: String(localized: "Position"), subtitle: selectedPosition.title) {
                        positionSchematic
                    }
                }

                if selectedLayout != .edge {
                    SettingsRowDivider()

                    SettingsRow(
                        title: String(localized: "Free Movement"),
                        subtitle: String(localized: "Drag the widget by its background to move it. Its position is saved.")
                    ) {
                        Toggle(String(localized: "Free Movement"), isOn: $freeMoveEnabled)
                            .labelsHidden()
                    }

                    if freeMoveEnabled {
                        SettingsRowDivider()

                        SettingsRow(
                            title: String(localized: "Lock Position"),
                            subtitle: String(localized: "Prevent accidental dragging.")
                        ) {
                            Toggle(String(localized: "Lock Position"), isOn: $positionLocked)
                                .labelsHidden()
                        }

                        SettingsRowDivider()

                        SettingsRow(
                            title: String(localized: "Reset Position"),
                            subtitle: String(localized: "Return to “\(selectedPosition.title)”.")
                        ) {
                            Button(String(localized: "Reset")) {
                                UserDefaults.standard.removeObject(
                                    forKey: WidgetPreferences.originXKey
                                )
                                UserDefaults.standard.removeObject(
                                    forKey: WidgetPreferences.originTopYKey
                                )
                                WidgetPlacementStore.removeAll(layout: selectedLayout)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Мини-экран: кликабельные точки в шести позициях.
    private var positionSchematic: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)

            VStack {
                positionRow(top: true)
                Spacer(minLength: 8)
                positionRow(top: false)
            }
            .padding(8)
        }
        .frame(width: 220, height: 76)
    }

    private func positionRow(top: Bool) -> some View {
        let positions: [NotchWidgetPosition] = top
            ? [.topLeading, .topCenter, .topTrailing]
            : [.bottomLeading, .bottomCenter, .bottomTrailing]

        return HStack {
            ForEach(positions) { position in
                positionDot(position)

                if position != positions.last {
                    Spacer()
                }
            }
        }
    }

    private func positionDot(_ position: NotchWidgetPosition) -> some View {
        let isSelected = selectedPosition == position

        return Button {
            widgetPositionRawValue = position.rawValue
        } label: {
            Capsule()
                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.22))
                .frame(width: 34, height: 10)
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                            lineWidth: 1
                        )
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(position.title)
        .accessibilityLabel(position.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Поведение окна

    private var windowBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: String(localized: "Window Behavior"),
                subtitle: String(localized: "How the widget behaves around other windows and Spaces.")
            )

            SettingsGroup {
                SettingsRow(
                    title: String(localized: "Keep on Top"),
                    subtitle: String(localized: "Keep the widget above regular windows.")
                ) {
                    Toggle(String(localized: "Keep on Top"), isOn: $alwaysOnTop)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Show on All Desktops"),
                    subtitle: String(localized: "The widget appears on every Space.")
                ) {
                    Toggle(String(localized: "Show on All Desktops"), isOn: $allSpaces)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Hide in Full Screen"),
                    subtitle: String(localized: "Do not show the widget over full-screen apps.")
                ) {
                    Toggle(String(localized: "Hide in Full Screen"), isOn: $hideInFullscreen)
                        .labelsHidden()
                }

            }
        }
    }

    // MARK: Оформление

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if selectedLayout.supportsOptionalLyrics {
                SettingsSection(title: String(localized: "Content")) {
                    SettingsGroup {
                        SettingsRow(
                            title: String(localized: "Replace Progress with Lyrics"),
                            subtitle: String(localized: "For the current “\(selectedLayout.title)” template.")
                        ) {
                            Toggle(String(localized: "Song Lyrics"), isOn: $lyricsEnabled)
                                .labelsHidden()
                        }
                    }
                }
            }

            if selectedLayout == .lyricStrip {
                SettingsSection(title: String(localized: "Size")) {
                    SettingsGroup {
                        SettingsRow(title: String(localized: "Strip Width"), subtitle: String(localized: "Stays 56 pt tall, including on hover.")) {
                            SettingsValueSlider(
                                value: Binding(get: { NotchPreferences.clampedWidth(width) + 80 },
                                               set: { width = NotchPreferences.clampedWidth($0 - 80) }),
                                range: 320...500, step: 5,
                                text: String(localized: "\(Int(NotchPreferences.clampedWidth(width) + 80)) pt")
                            )
                        }
                    }
                    Text(String(localized: "One line of lyrics on a quiet background. Without synchronized lyrics, the title and artist appear instead. Artwork, the equalizer and effects are disabled here; other templates keep their settings."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if selectedLayout == .edge {
                SettingsSection(title: String(localized: "Colors")) {
                    SettingsGroup {
                        SettingsRow(title: String(localized: "Colored Progress"), subtitle: String(localized: "A small accent below the controls.")) {
                            Toggle(String(localized: "Colored Progress"), isOn: $coloredProgress).labelsHidden()
                        }
                        SettingsRowDivider()
                        colorSourceRow
                    }
                    Text(String(localized: "Edge keeps a fixed size and a quiet appearance without an equalizer or pulse."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                SettingsSection(title: String(localized: "Size and Colors")) {
                    SettingsGroup {
                        SettingsRow(
                            title: String(localized: "Width"),
                            subtitle: String(localized: "Base pill width. Card sizes adjust to match.")
                        ) {
                            SettingsValueSlider(
                                value: widgetWidth,
                                range: NotchPreferences.widthRange,
                                step: NotchPreferences.widthStep,
                                text: String(localized: "\(Int(NotchPreferences.clampedWidth(width))) px")
                            )
                        }
                        SettingsRowDivider()
                        colorSourceRow
                        if selectedLayout.usesProgressColor {
                            SettingsRowDivider()
                            SettingsRow(title: String(localized: "Colored Progress"), subtitle: String(localized: "An accent on the progress bar and lyrics.")) {
                                Toggle(String(localized: "Colored Progress"), isOn: $coloredProgress).labelsHidden()
                            }
                        }
                        if selectedLayout != .artworkSquare {
                            SettingsRowDivider()
                            SettingsRow(title: String(localized: "Artwork Glass"), subtitle: String(localized: "Blurred artwork replaces the black card background.")) {
                                Toggle(String(localized: "Artwork Glass"), isOn: $glassBackground).labelsHidden()
                            }
                            if !selectedLayout.hasEqualizer {
                                SettingsRowDivider()
                                SettingsRow(title: String(localized: "Colored Background"), subtitle: String(localized: "A soft gradient from the selected palette.")) {
                                    Toggle(String(localized: "Colored Background"), isOn: $coloredWaveform).labelsHidden()
                                }
                            }
                        }
                    }
                }

                if selectedLayout.hasEqualizer {
                    SettingsSection(title: String(localized: "Equalizer")) {
                        SettingsGroup {
                            SettingsRow(title: String(localized: "Colored Waveform"), subtitle: String(localized: "Use the selected palette.")) {
                                Toggle(String(localized: "Colored Waveform"), isOn: $coloredWaveform).labelsHidden()
                            }
                            SettingsRowDivider()
                            SettingsRow(title: String(localized: "Sensitivity"), subtitle: String(localized: "How strongly the waveform responds to sound.")) {
                                SettingsValueSlider(
                                    value: widgetSensitivity,
                                    range: NotchPreferences.equalizerSensitivityRange,
                                    step: NotchPreferences.equalizerSensitivityStep,
                                    text: String(format: String(localized: "%.1f×"), locale: Locale.current, NotchPreferences.clampedEqualizerSensitivity(equalizerSensitivity))
                                )
                                .accessibilityLabel(String(localized: "Equalizer Sensitivity"))
                            }
                        }
                    }
                }

                SettingsDisclosure(title: String(localized: "Additional Effects"), subtitle: String(localized: "Shimmering outline and pulse.")) {
                    SettingsGroup {
                        SettingsRow(title: String(localized: "Shimmering Outline"), subtitle: String(localized: "The outline shifts smoothly through the artwork palette.")) {
                            Toggle(String(localized: "Shimmering Outline"), isOn: $outlineShimmer).labelsHidden()
                        }
                        if outlineShimmer {
                            SettingsRowDivider()
                            SettingsRow(title: String(localized: "Outline Width")) {
                                SettingsValueSlider(
                                    value: widgetOutlineWidth,
                                    range: NotchPreferences.outlineWidthRange,
                                    step: NotchPreferences.outlineWidthStep,
                                    text: String(format: String(localized: "%.1f px"), locale: Locale.current, NotchPreferences.clampedOutlineWidth(outlineWidth))
                                )
                            }
                        }
                        SettingsRowDivider()
                        SettingsRow(title: String(localized: "Pulse"), subtitle: String(localized: "Responds to volume by scaling or glowing.")) {
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
        }
    }

    private var colorSourceRow: some View {
        SettingsRow(title: String(localized: "Color Source"), subtitle: String(localized: "Artwork palette or system accent.")) {
            Picker(String(localized: "Color Source"), selection: colorSource) {
                ForEach(NotchColorSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .settingsMenuControl()
        }
    }

}
