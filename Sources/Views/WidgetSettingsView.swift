import SwiftUI

struct WidgetSettingsView: View {
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

    var body: some View {
        SettingsPage(
            title: "Виджет",
            subtitle: "Плавающая панель для экранов без чёлки: пилюля или карточки постоянного размера."
        ) {
            activationCard
            layoutSection
            placementSection
            windowBehaviorSection
            appearanceSection
        }
    }

    // MARK: Активация

    private var activationCard: some View {
        HStack(spacing: 12) {
            Image(
                systemName: selectedMode == .floatingWidget
                    ? "checkmark.circle.fill"
                    : "rectangle.on.rectangle"
            )
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(selectedMode == .floatingWidget ? Color.green : Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedMode == .floatingWidget ? "Режим виджета активен" : "Виджет выключен")
                    .font(.headline)

                Text(
                    selectedMode == .floatingWidget
                        ? "Все настройки виджета собраны на этой вкладке."
                        : "Настройки сохранятся; включить виджет можно одной кнопкой."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if selectedMode != .floatingWidget {
                Button("Использовать виджет") {
                    selectedModeRawValue = OverlayMode.floatingWidget.rawValue
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    // MARK: Раскладка

    private var layoutSection: some View {
        SettingsSection(
            title: "Раскладка",
            subtitle: "Форма и размер плавающей панели.",
            symbolName: "square.grid.2x2"
        ) {
            ForEach(NotchWidgetLayoutFamily.allCases) { family in
                VStack(alignment: .leading, spacing: 6) {
                    Text(family.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 148), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(family.layouts) { layout in
                            layoutCard(layout)
                        }
                    }
                }
            }

            if selectedLayout != .edge {
                SettingsGroup {
                    SettingsRow(
                        title: "Текст песни в плеере",
                        subtitle: "Заменяет полосу прогресса синхронизированным текстом (в «Тексте песни» и «Караоке» включён всегда)."
                    ) {
                        Toggle("Текст песни", isOn: $lyricsEnabled)
                            .labelsHidden()
                    }
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
                    Text(layout.title)
                        .font(.system(size: 11, weight: .semibold))

                    Text(layout.summary)
                        .font(.system(size: 9))
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
    }

    // MARK: Расположение

    private var placementSection: some View {
        SettingsSection(
            title: "Расположение",
            subtitle: "Где держать виджет и можно ли его перетаскивать.",
            symbolName: "arrow.up.and.down.and.arrow.left.and.right"
        ) {
            if selectedLayout == .edge {
                Picker("Край экрана", selection: $edgeOnRight) {
                    Text("Слева").tag(false)
                    Text("Справа").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                Text("72 × 224 pt · по центру выбранного края, с учётом Dock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                positionSchematic
            }

            SettingsGroup {
                SettingsRow(
                    title: "Показывать на",
                    subtitle: "Экран, на котором живёт виджет."
                ) {
                    DisplayTargetPicker(selection: $displayTargetRawValue)
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

                    SettingsRowDivider()

                    SettingsRow(
                        title: "Сбросить позицию",
                        subtitle: "Вернуть виджет к выбранной точке у края экрана."
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

    /// Мини-экран: кликабельные точки в шести позициях.
    private var positionSchematic: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.14), lineWidth: 1)

                // строка меню
                VStack {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(height: 8)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 10,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 10
                            )
                        )
                    Spacer()
                }

                VStack {
                    positionRow(top: true)
                    Spacer()
                    positionRow(top: false)
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
                .padding(.horizontal, 10)
            }
            .frame(width: 240, height: 140)
            .opacity(freeMoveEnabled ? 0.4 : 1)

            Text(
                freeMoveEnabled
                    ? "Свободное перемещение включено — позиция задаётся перетаскиванием."
                    : "Нажмите на место, где держать виджет."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .allowsHitTesting(!freeMoveEnabled)
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
                .frame(width: 34, height: 12)
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                            lineWidth: 1
                        )
                }
                .contentShape(Capsule().scale(1.6))
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

                if selectedLayout != .edge {
                    SettingsRowDivider()

                    SettingsRow(
                        title: "Зафиксировать позицию",
                        subtitle: "Запрещает случайное перетаскивание виджета."
                    ) {
                        Toggle("Зафиксировать позицию", isOn: $positionLocked)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: Оформление

    private var appearanceSection: some View {
        SettingsSection(
            title: "Оформление",
            subtitle: "Эффекты виджета — независимо от настроек чёлки.",
            symbolName: "paintpalette"
        ) {
            if selectedLayout == .edge {
                SettingsGroup {
                    SettingsRow(title: "Цветной прогресс", subtitle: "Небольшой акцент под кнопками.") {
                        Toggle("Цветной прогресс", isOn: $coloredProgress).labelsHidden()
                    }
                    SettingsRowDivider()
                    SettingsRow(title: "Источник цвета", subtitle: "Палитра обложки или системный акцент.") {
                        Picker("Источник цвета", selection: colorSource) {
                            ForEach(NotchColorSource.allCases) { source in
                                Text(source.title).tag(source)
                            }
                        }.labelsHidden().frame(width: 190)
                    }
                }
                Text("Edge сохраняет постоянный размер и спокойное оформление без эквалайзера и пульсации.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
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

                    SettingsRow(
                        title: "Цветной прогресс",
                        subtitle: "Акцент палитры на полосе воспроизведения и тексте."
                    ) {
                        Toggle("Цветной прогресс", isOn: $coloredProgress)
                            .labelsHidden()
                    }

                    SettingsRowDivider()

                    SettingsRow(
                        title: "Цветная волна",
                        subtitle: "Подсвечивать эквалайзер палитрой обложки."
                    ) {
                        Toggle("Цветная волна", isOn: $coloredWaveform)
                            .labelsHidden()
                    }

                    SettingsRowDivider()

                    SettingsRow(
                        title: "Источник цвета",
                        subtitle: "Откуда берутся акцентные цвета виджета."
                    ) {
                        Picker("Источник цвета", selection: colorSource) {
                            ForEach(NotchColorSource.allCases) { source in
                                Text(source.title).tag(source)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 190)
                    }

                    SettingsRowDivider()

                    SettingsRow(
                        title: "Чувствительность эквалайзера",
                        subtitle: "Насколько активно волна реагирует на звук."
                    ) {
                        SettingsValueSlider(
                            value: widgetSensitivity,
                            range: NotchPreferences.equalizerSensitivityRange,
                            step: NotchPreferences.equalizerSensitivityStep,
                            text: String(
                                format: "%.1f×",
                                NotchPreferences.clampedEqualizerSensitivity(equalizerSensitivity)
                            )
                        )
                    }

                    SettingsRowDivider()

                    SettingsRow(
                        title: "Стекло из обложки",
                        subtitle: "Размытая обложка вместо чёрного фона карточек."
                    ) {
                        Toggle("Стекло из обложки", isOn: $glassBackground)
                            .labelsHidden()
                    }

                    SettingsRowDivider()

                    SettingsRow(
                        title: "Переливающийся контур",
                        subtitle: "Обводка виджета плавно меняет цвет по палитре обложки."
                    ) {
                        Toggle("Переливающийся контур", isOn: $outlineShimmer)
                            .labelsHidden()
                    }

                    if outlineShimmer {
                        SettingsRowDivider()

                        SettingsRow(
                            title: "Толщина контура",
                            subtitle: "Размер переливающейся обводки."
                        ) {
                            SettingsValueSlider(
                                value: widgetOutlineWidth,
                                range: NotchPreferences.outlineWidthRange,
                                step: NotchPreferences.outlineWidthStep,
                                text: String(
                                    format: "%.1f px",
                                    NotchPreferences.clampedOutlineWidth(outlineWidth)
                                )
                            )
                        }
                    }

                    SettingsRowDivider()

                    SettingsRow(
                        title: "Пульсация",
                        subtitle: "Реакция виджета на громкость: масштаб или свечение."
                    ) {
                        Picker("Пульсация", selection: pulseMode) {
                            ForEach(NotchPulseMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
            }
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
