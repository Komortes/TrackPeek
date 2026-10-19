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

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: 12)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach((browsedFamily ?? selectedLayout.family).layouts) { layout in
                    layoutCard(layout)
                }
            }

        }
    }

    private func layoutCard(_ layout: NotchWidgetLayout) -> some View {
        let isSelected = selectedLayout == layout

        return Button {
            widgetLayoutRawValue = layout.rawValue
        } label: {
            VStack(spacing: 7) {
                WidgetLayoutPreview(layout: layout)
                    .frame(height: 64)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 1) {
                    HStack(spacing: 5) {
                        Text(layout.title)
                            .font(.system(size: 12, weight: .semibold))
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.tint)
                        }
                    }

                    Text(layout.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2, reservesSpace: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(.thinMaterial),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(layout.summary)
        .accessibilityLabel(layout.title)
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

/// Схематичное мини-превью раскладки для карточек выбора.
struct WidgetLayoutPreview: View {
    let layout: NotchWidgetLayout

    private let accent = Color.accentColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))

            preview
                .padding(8)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch layout {
        case .pill:
            Capsule()
                .fill(Color.black)
                .frame(width: 84, height: 16)
                .overlay {
                    HStack(spacing: 3) {
                        miniSquare(6)
                        Capsule().fill(.white.opacity(0.35)).frame(width: 30, height: 3)
                        miniBars
                    }
                }
        case .edge:
            card(width: 24, height: 70) {
                VStack(spacing: 5) {
                    miniSquare(16)
                    Image(systemName: "backward.fill")
                    Image(systemName: "play.circle.fill")
                    Image(systemName: "forward.fill")
                }
                .font(.system(size: 6, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            }
        case .miniBar:
            Capsule()
                .fill(Color.black)
                .frame(width: 110, height: 18)
                .overlay {
                    HStack(spacing: 4) {
                        miniSquare(8)
                        Capsule().fill(.white.opacity(0.35)).frame(width: 34, height: 3)
                        controlsDots
                    }
                }
        case .cardHorizontal:
            card(width: 110, height: 52) {
                HStack(spacing: 6) {
                    miniSquare(24)
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(.white.opacity(0.5)).frame(width: 40, height: 4)
                        Capsule().fill(accent).frame(width: 52, height: 3)
                        controlsDots
                    }
                }
            }
        case .cardVertical:
            card(width: 56, height: 60) {
                VStack(spacing: 4) {
                    miniSquare(22)
                    Capsule().fill(.white.opacity(0.5)).frame(width: 28, height: 3)
                    controlsDots
                }
            }
        case .artworkSquare:
            card(width: 52, height: 52) {
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(.white.opacity(0.22))
                        .frame(height: 14)
                        .overlay { controlsDots }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.7), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
            }
        case .lyricStrip:
            card(width: 118, height: 25) {
                HStack(spacing: 5) {
                    Image(systemName: "quote.opening").font(.system(size: 7)).foregroundStyle(.white.opacity(0.4))
                    Capsule().fill(.white.opacity(0.85)).frame(width: 75, height: 4)
                }
            }
        case .lyricsCard:
            card(width: 110, height: 34) {
                HStack(spacing: 5) {
                    miniSquare(16)
                    VStack(alignment: .leading, spacing: 3) {
                        Capsule().fill(accent).frame(width: 46, height: 4)
                        Capsule().fill(.white.opacity(0.3)).frame(width: 34, height: 3)
                    }
                    controlsDots
                }
            }
        case .karaokeCard:
            card(width: 96, height: 58) {
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(.white.opacity(0.25)).frame(width: 40, height: 3)
                    Capsule().fill(accent).frame(width: 64, height: 5)
                    Capsule().fill(.white.opacity(0.4)).frame(width: 50, height: 3)
                    Capsule().fill(.white.opacity(0.25)).frame(width: 44, height: 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .equalizerCard:
            card(width: 96, height: 46) {
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<9, id: \.self) { index in
                            Capsule()
                                .fill(accent.opacity(0.85))
                                .frame(width: 4, height: [10, 16, 22, 14, 18, 24, 12, 18, 10][index])
                        }
                    }
                    Capsule().fill(.white.opacity(0.35)).frame(width: 48, height: 3)
                }
            }
        }
    }

    private func card(
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> some View
    ) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.black)
            .frame(width: width, height: height)
            .overlay {
                content()
                    .padding(5)
            }
    }

    private func miniSquare(_ side: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: max(2, side * 0.2), style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accent.opacity(0.8), .purple.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: side, height: side)
    }

    private var miniBars: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(accent)
                    .frame(width: 2, height: [5, 8, 6][index])
            }
        }
    }

    private var controlsDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 4, height: 4)
            }
        }
    }
}
