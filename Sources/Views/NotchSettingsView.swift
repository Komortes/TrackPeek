import Foundation
import SwiftUI

struct NotchSettingsView: View {
    private enum Page: String, CaseIterable {
        case appearance = "Вид"
        case behavior = "Поведение"
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
        SettingsPage(title: "Чёлка") {
            activationStatus

            Picker("Настройки чёлки", selection: $selectedPage) {
                ForEach(Page.allCases, id: \.self) { page in
                    Text(page.rawValue).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 320)

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
        SettingsSection(title: "Содержимое") {
            SettingsGroup {
                SettingsRow(title: "Раскладка", subtitle: (NotchContentLayout(rawValue: contentLayoutRaw) ?? .fallback).summary) {
                    Picker("Раскладка чёлки", selection: $contentLayoutRaw) {
                        ForEach(NotchContentLayout.allCases) { layout in
                            Text(layout.title).tag(layout.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
            }

            if isFocusLayout {
                Text("«Фокус» скрывает обложку, эквалайзер, тексты и эффекты. Настройки полного плеера сохранены.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isPanelModeActive: Bool {
        selectedMode == .notch
    }

    private var activationTitle: String {
        switch selectedMode {
        case .notch: "Чёлка включена"
        case .floatingWidget: "Сейчас включён виджет"
        case .off: "Экранный плеер выключен"
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
                Button("Включить чёлку") {
                    selectedModeRawValue = OverlayMode.notch.rawValue
                }
                .controlSize(.small)
            }
        }
    }

    private var displaySection: some View {
        SettingsSection(title: "Размещение") {
            SettingsGroup {
                SettingsRow(title: "Экран") {
                    DisplayTargetPicker(selection: $displayTargetRawValue)
                }
            }
        }
    }

    private var interactionSection: some View {
        SettingsSection(title: "Раскрытие") {
            SettingsGroup {
                SettingsRow(
                    title: "По наведению",
                    subtitle: "Открывать плеер под указателем."
                ) {
                    Toggle("По наведению", isOn: $hoverEnabled)
                        .labelsHidden()
                }

                if hoverEnabled {
                    SettingsRowDivider()

                    SettingsRow(
                        title: "Задержка наведения",
                        subtitle: "Пауза перед раскрытием."
                    ) {
                        SettingsValueSlider(
                            value: notchHoverDelay,
                            range: NotchPreferences.hoverDelayRange,
                            step: NotchPreferences.hoverDelayStep,
                            text: String(format: "%.2f с", NotchPreferences.clampedHoverDelay(hoverDelay))
                        )
                    }
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "По нажатию",
                    subtitle: "Оставлять плеер открытым после нажатия."
                ) {
                    Toggle("По нажатию", isOn: $clickEnabled)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(title: "Тактильный отклик", subtitle: "При раскрытии панели.") {
                    Toggle("Тактильный отклик", isOn: $hapticFeedback)
                        .labelsHidden()
                }
            }
        }
    }

    private var notificationSection: some View {
        SettingsSection(title: "Смена трека") {
            SettingsGroup {
                SettingsRow(
                    title: "Показывать новый трек",
                    subtitle: "Ненадолго раскрывать чёлку."
                ) {
                    Toggle("Показывать новый трек", isOn: $notificationsEnabled)
                        .labelsHidden()
                }

                if notificationsEnabled {
                    SettingsRowDivider()

                    SettingsRow(
                        title: "Длительность"
                    ) {
                        SettingsValueSlider(
                            value: notchNotificationDuration,
                            range: NotchPreferences.notificationDurationRange,
                            step: NotchPreferences.notificationDurationStep,
                            text: String(
                                format: "%.2f с",
                                NotchPreferences.clampedNotificationDuration(notificationDuration)
                            )
                        )
                    }
                }
            }
        }
    }

    private var sizeSection: some View {
        SettingsSection(title: "Размер и форма") {
            if !isFocusLayout {
                notchSizePreview
            }

            SettingsGroup {
                SettingsRow(
                    title: "Ширина",
                    subtitle: "В закрытом состоянии."
                ) {
                    SettingsValueSlider(
                        value: notchWidth,
                        range: NotchPreferences.widthRange,
                        step: NotchPreferences.widthStep,
                        text: "\(Int(NotchPreferences.clampedWidth(width))) px"
                    )
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Коррекция высоты",
                    subtitle: "Подстройка под верхний край экрана."
                ) {
                    SettingsValueSlider(
                        value: notchHeightAdjustment,
                        range: NotchPreferences.heightAdjustmentRange,
                        step: NotchPreferences.heightAdjustmentStep,
                        text: String(
                            format: "%+.0f px",
                            NotchPreferences.clampedHeightAdjustment(heightAdjustment)
                        )
                    )
                }

                if !isFocusLayout {
                    SettingsRowDivider()

                    SettingsRow(title: "Скругление") {
                        SettingsValueSlider(
                            value: notchCornerRadius,
                            range: NotchPreferences.cornerRadiusRange,
                            step: NotchPreferences.cornerRadiusStep,
                            text: "\(Int(NotchPreferences.clampedCornerRadius(cornerRadius))) px"
                        )
                    }
                }
            }
        }
    }

    private var contentSection: some View {
        SettingsSection(title: "Название и цвет") {
            SettingsGroup {
                SettingsRow(title: "Название в закрытом виде") {
                    Picker("Название", selection: songInfoVisibility) {
                        ForEach(NotchSongInfoVisibility.allCases) { visibility in
                            Text(visibility.title).tag(visibility)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 210)
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Цветной прогресс"
                ) {
                    Toggle("Цветной прогресс", isOn: $coloredProgress)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Источник цвета"
                ) {
                    Picker("Источник цвета", selection: colorSource) {
                        ForEach(NotchColorSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
            }
        }
    }

    private var equalizerSection: some View {
        SettingsSection(title: "Эквалайзер") {
            SettingsGroup {
                SettingsRow(title: "Цветная волна", subtitle: "Использовать выбранную палитру.") {
                    Toggle("Цветная волна", isOn: $coloredWaveform)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(title: "Чувствительность", subtitle: "Насколько активно волна реагирует на звук.") {
                    SettingsValueSlider(
                        value: notchEqualizerSensitivity,
                        range: NotchPreferences.equalizerSensitivityRange,
                        step: NotchPreferences.equalizerSensitivityStep,
                        text: String(
                            format: "%.1f×",
                            NotchPreferences.clampedEqualizerSensitivity(equalizerSensitivity)
                        )
                    )
                    .accessibilityLabel("Чувствительность эквалайзера")
                }
            }
        }
    }

    private var effectsSection: some View {
        SettingsDisclosure(title: "Визуальные эффекты", subtitle: "Контур и пульсация") {
            SettingsGroup {
                SettingsRow(
                    title: "Переливающийся контур",
                    subtitle: "Плавная смена цветов по краям панели."
                ) {
                    Toggle("Переливающийся контур", isOn: $outlineShimmer)
                        .labelsHidden()
                }

                if outlineShimmer {
                    SettingsRowDivider()

                    SettingsRow(
                        title: "Толщина контура"
                    ) {
                        SettingsValueSlider(
                            value: notchOutlineWidth,
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
                    subtitle: "Реакция на громкость звука."
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

            Text("Закрытая панель")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}
