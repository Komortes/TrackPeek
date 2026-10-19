import SwiftUI

struct WidgetSettingsView: View {
    private enum Page: String, CaseIterable, Identifiable {
        case template = "Шаблон"
        case placement = "Размещение"
        case appearance = "Оформление"

        var id: Self { self }
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
        SettingsPage(title: "Виджет", subtitle: "Плавающий плеер на рабочем столе.") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Настройки виджета", selection: $selectedPage) {
                    ForEach(Page.allCases) { page in
                        Text(page.rawValue).tag(page)
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
                selectedMode == .floatingWidget ? "Виджет включён" : "Виджет выключен",
                systemImage: selectedMode == .floatingWidget ? "checkmark.circle.fill" : "rectangle.on.rectangle"
            )
            .foregroundStyle(.secondary)
            .font(.callout)

            Text("· \(selectedLayout.title)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            if selectedMode != .floatingWidget {
                Button("Включить виджет") {
                    selectedModeRawValue = OverlayMode.floatingWidget.rawValue
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: Шаблон

    private var layoutSection: some View {
        SettingsSection(title: "Шаблоны", subtitle: "Просмотр категории не меняет выбранный шаблон.") {
            Picker("Категория шаблонов", selection: layoutFamily) {
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
            title: "Расположение",
            subtitle: "Где держать виджет и можно ли его перетаскивать.",
            symbolName: "arrow.up.and.down.and.arrow.left.and.right"
        ) {
            SettingsGroup {
                SettingsRow(
                    title: "Монитор",
                    subtitle: "Где показывать виджет."
                ) {
                    DisplayTargetPicker(selection: $displayTargetRawValue)
                }

                if selectedLayout == .edge {
                    SettingsRowDivider()
                    SettingsRow(title: "Край экрана", subtitle: "По центру выбранного края, с учётом Dock.") {
                        Picker("Край экрана", selection: $edgeOnRight) {
                            Text("Слева").tag(false)
                            Text("Справа").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }
                } else if !freeMoveEnabled {
                    SettingsRowDivider()
                    SettingsRow(title: "Позиция", subtitle: selectedPosition.title) {
                        positionSchematic
                    }
                }

                if selectedLayout != .edge {
                    SettingsRowDivider()

                    SettingsRow(
                        title: "Свободное перемещение",
                        subtitle: "Перетаскивайте виджет за фон в любое место; позиция запоминается."
                    ) {
                        Toggle("Свободное перемещение", isOn: $freeMoveEnabled)
                            .labelsHidden()
                    }

                    if freeMoveEnabled {
                        SettingsRowDivider()

                        SettingsRow(
                            title: "Зафиксировать позицию",
                            subtitle: "Защита от случайного перетаскивания."
                        ) {
                            Toggle("Зафиксировать позицию", isOn: $positionLocked)
                                .labelsHidden()
                        }

                        SettingsRowDivider()

                        SettingsRow(
                            title: "Сбросить позицию",
                            subtitle: "Вернуть к точке «\(selectedPosition.title)»."
                        ) {
                            Button("Сбросить") {
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
                title: "Поведение окна",
                subtitle: "Как виджет ведёт себя относительно других окон и Spaces."
            )

            SettingsGroup {
                SettingsRow(
                    title: "Поверх остальных окон",
                    subtitle: "Виджет не перекрывается обычными окнами."
                ) {
                    Toggle("Поверх остальных окон", isOn: $alwaysOnTop)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "На всех рабочих столах",
                    subtitle: "Виджет виден на каждом Space."
                ) {
                    Toggle("На всех рабочих столах", isOn: $allSpaces)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Скрывать в полноэкранном режиме",
                    subtitle: "Не показывать виджет поверх fullscreen-приложений."
                ) {
                    Toggle("Скрывать в полноэкранном режиме", isOn: $hideInFullscreen)
                        .labelsHidden()
                }

            }
        }
    }

    // MARK: Оформление

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if selectedLayout.supportsOptionalLyrics {
                SettingsSection(title: "Содержимое") {
                    SettingsGroup {
                        SettingsRow(
                            title: "Текст песни вместо прогресса",
                            subtitle: "Для текущего шаблона «\(selectedLayout.title)»."
                        ) {
                            Toggle("Текст песни", isOn: $lyricsEnabled)
                                .labelsHidden()
                        }
                    }
                }
            }

            if selectedLayout == .lyricStrip {
                SettingsSection(title: "Размер") {
                    SettingsGroup {
                        SettingsRow(title: "Ширина строки", subtitle: "Высота остаётся 56 pt, в том числе при наведении.") {
                            SettingsValueSlider(
                                value: Binding(get: { NotchPreferences.clampedWidth(width) + 80 },
                                               set: { width = NotchPreferences.clampedWidth($0 - 80) }),
                                range: 320...500, step: 5,
                                text: "\(Int(NotchPreferences.clampedWidth(width) + 80)) pt"
                            )
                        }
                    }
                    Text("Одна строка песни на спокойном фоне. Без синхронизации — название и исполнитель. Обложка, эквалайзер и эффекты здесь отключены; настройки других шаблонов сохранены.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if selectedLayout == .edge {
                SettingsSection(title: "Цвета") {
                    SettingsGroup {
                        SettingsRow(title: "Цветной прогресс", subtitle: "Небольшой акцент под кнопками.") {
                            Toggle("Цветной прогресс", isOn: $coloredProgress).labelsHidden()
                        }
                        SettingsRowDivider()
                        colorSourceRow
                    }
                    Text("Edge сохраняет постоянный размер и спокойное оформление без эквалайзера и пульсации.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                SettingsSection(title: "Размер и цвета") {
                    SettingsGroup {
                        SettingsRow(
                            title: "Ширина",
                            subtitle: "Базовая ширина пилюли; размеры карточек следуют за ней."
                        ) {
                            SettingsValueSlider(
                                value: widgetWidth,
                                range: NotchPreferences.widthRange,
                                step: NotchPreferences.widthStep,
                                text: "\(Int(NotchPreferences.clampedWidth(width))) px"
                            )
                        }
                        SettingsRowDivider()
                        colorSourceRow
                        if selectedLayout.usesProgressColor {
                            SettingsRowDivider()
                            SettingsRow(title: "Цветной прогресс", subtitle: "Акцент на полосе воспроизведения и тексте.") {
                                Toggle("Цветной прогресс", isOn: $coloredProgress).labelsHidden()
                            }
                        }
                        if selectedLayout != .artworkSquare {
                            SettingsRowDivider()
                            SettingsRow(title: "Стекло из обложки", subtitle: "Размытая обложка вместо чёрного фона карточек.") {
                                Toggle("Стекло из обложки", isOn: $glassBackground).labelsHidden()
                            }
                            if !selectedLayout.hasEqualizer {
                                SettingsRowDivider()
                                SettingsRow(title: "Цветной фон", subtitle: "Мягкий градиент из выбранной палитры.") {
                                    Toggle("Цветной фон", isOn: $coloredWaveform).labelsHidden()
                                }
                            }
                        }
                    }
                }

                if selectedLayout.hasEqualizer {
                    SettingsSection(title: "Эквалайзер") {
                        SettingsGroup {
                            SettingsRow(title: "Цветная волна", subtitle: "Использовать выбранную палитру.") {
                                Toggle("Цветная волна", isOn: $coloredWaveform).labelsHidden()
                            }
                            SettingsRowDivider()
                            SettingsRow(title: "Чувствительность", subtitle: "Насколько активно волна реагирует на звук.") {
                                SettingsValueSlider(
                                    value: widgetSensitivity,
                                    range: NotchPreferences.equalizerSensitivityRange,
                                    step: NotchPreferences.equalizerSensitivityStep,
                                    text: String(format: "%.1f×", NotchPreferences.clampedEqualizerSensitivity(equalizerSensitivity))
                                )
                                .accessibilityLabel("Чувствительность эквалайзера")
                            }
                        }
                    }
                }

                SettingsDisclosure(title: "Дополнительные эффекты", subtitle: "Переливающийся контур и пульсация.") {
                    SettingsGroup {
                        SettingsRow(title: "Переливающийся контур", subtitle: "Обводка плавно меняет цвет по палитре обложки.") {
                            Toggle("Переливающийся контур", isOn: $outlineShimmer).labelsHidden()
                        }
                        if outlineShimmer {
                            SettingsRowDivider()
                            SettingsRow(title: "Толщина контура") {
                                SettingsValueSlider(
                                    value: widgetOutlineWidth,
                                    range: NotchPreferences.outlineWidthRange,
                                    step: NotchPreferences.outlineWidthStep,
                                    text: String(format: "%.1f px", NotchPreferences.clampedOutlineWidth(outlineWidth))
                                )
                            }
                        }
                        SettingsRowDivider()
                        SettingsRow(title: "Пульсация", subtitle: "Реакция на громкость: масштаб или свечение.") {
                            Picker("Пульсация", selection: pulseMode) {
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
        SettingsRow(title: "Источник цвета", subtitle: "Палитра обложки или системный акцент.") {
            Picker("Источник цвета", selection: colorSource) {
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
