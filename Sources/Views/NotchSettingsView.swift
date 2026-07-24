import Foundation
import SwiftUI

struct NotchSettingsView: View {
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

    private var displayTarget: Binding<NotchDisplayTarget> {
        Binding(
            get: { NotchDisplayTarget(rawValue: displayTargetRawValue) ?? .fallback },
            set: { displayTargetRawValue = $0.rawValue }
        )
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
        SettingsPage(
            title: "Чёлка",
            subtitle: "Компактный плеер у верхнего края экрана, который раскрывается по вашему сценарию."
        ) {
            activationCard
            generalSection
            interactionSection
            notificationSection
            appearanceSection
        }
    }

    private var isPanelModeActive: Bool {
        selectedMode == .notch || selectedMode == .floatingWidget
    }

    private var activationTitle: String {
        switch selectedMode {
        case .notch: "Режим чёлки активен"
        case .floatingWidget: "Режим виджета активен"
        case .off: "Экранный плеер выключен"
        }
    }

    private var activationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: isPanelModeActive ? "checkmark.circle.fill" : "macbook")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isPanelModeActive ? Color.green : Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(activationTitle)
                    .font(.headline)

                Text(
                    isPanelModeActive
                        ? "Панель уже использует настройки ниже."
                        : "Настройки сохранятся; включить панель можно одной кнопкой."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if !isPanelModeActive {
                Button("Использовать чёлку") {
                    selectedModeRawValue = OverlayMode.notch.rawValue
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

    private var generalSection: some View {
        SettingsSection(
            title: "Основные",
            subtitle: "Включение, экран и системная обратная связь.",
            symbolName: "gearshape"
        ) {
            SettingsGroup {
                SettingsRow(
                    title: "Показывать на",
                    subtitle: "Можно выбрать основной, встроенный или все экраны."
                ) {
                    Picker("Экран", selection: displayTarget) {
                        ForEach(NotchDisplayTarget.allCases) { target in
                            Label(target.title, systemImage: target.symbolName)
                                .tag(target)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 330)
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Тактильный отклик",
                    subtitle: "Лёгкий системный отклик при раскрытии панели."
                ) {
                    Toggle("Тактильный отклик", isOn: $hapticFeedback)
                        .labelsHidden()
                }
            }
        }
    }

    private var interactionSection: some View {
        SettingsSection(
            title: "Раскрытие",
            subtitle: "Настройте, как компактная панель превращается в плеер.",
            symbolName: "hand.tap"
        ) {
            SettingsGroup {
                SettingsRow(
                    title: "По наведению",
                    subtitle: "Раскрывать плеер, когда указатель задержался на панели."
                ) {
                    Toggle("По наведению", isOn: $hoverEnabled)
                        .labelsHidden()
                }

                if hoverEnabled {
                    SettingsRowDivider()

                    SettingsRow(
                        title: "Задержка наведения",
                        subtitle: "Небольшая пауза защищает от случайных раскрытий."
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
                    subtitle: "Нажатие фиксирует раскрытый плеер до сворачивания."
                ) {
                    Toggle("По нажатию", isOn: $clickEnabled)
                        .labelsHidden()
                }
            }
        }
    }

    private var notificationSection: some View {
        SettingsSection(
            title: "Смена трека",
            subtitle: "Панель может ненадолго раскрыться при начале новой песни.",
            symbolName: "bell.badge"
        ) {
            SettingsGroup {
                SettingsRow(
                    title: "Показывать новый трек",
                    subtitle: "Автоматически раскрывать чёлку при смене композиции."
                ) {
                    Toggle("Показывать новый трек", isOn: $notificationsEnabled)
                        .labelsHidden()
                }

                if notificationsEnabled {
                    SettingsRowDivider()

                    SettingsRow(
                        title: "Длительность",
                        subtitle: "Сколько времени держать уведомление раскрытым."
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

    private var appearanceSection: some View {
        SettingsSection(
            title: "Внешний вид",
            subtitle: "Размеры компактного состояния и акценты плеера.",
            symbolName: "paintpalette"
        ) {
            notchSizePreview

            SettingsGroup {
                SettingsRow(
                    title: "Ширина",
                    subtitle: "Ширина закрытой панели; раскрытая сохраняет пропорции."
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
                    subtitle: "Подстройка под геометрию верхней части экрана."
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

                SettingsRowDivider()

                SettingsRow(
                    title: "Скругление",
                    subtitle: "Радиус углов панели в закрытом состоянии."
                ) {
                    SettingsValueSlider(
                        value: notchCornerRadius,
                        range: NotchPreferences.cornerRadiusRange,
                        step: NotchPreferences.cornerRadiusStep,
                        text: "\(Int(NotchPreferences.clampedCornerRadius(cornerRadius))) px"
                    )
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Название в закрытом виде",
                    subtitle: "Определяет, когда показывать текущую композицию."
                ) {
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
                    title: "Цветной прогресс",
                    subtitle: "Голубой акцент на полосе воспроизведения."
                ) {
                    Toggle("Цветной прогресс", isOn: $coloredProgress)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Цветная волна",
                    subtitle: "Подсвечивать живой индикатор воспроизведения."
                ) {
                    Toggle("Цветная волна", isOn: $coloredWaveform)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Источник цвета",
                    subtitle: "Откуда берутся акцентные цвета панели."
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
                    title: "Переливающийся контур",
                    subtitle: "Боковая и нижняя грань панели плавно меняют цвет по палитре."
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
                    subtitle: "Реакция панели на громкость: масштаб или свечение контура."
                ) {
                    Picker("Пульсация", selection: pulseMode) {
                        ForEach(NotchPulseMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Чувствительность эквалайзера",
                    subtitle: "Насколько активно бары реагируют на звук."
                ) {
                    SettingsValueSlider(
                        value: notchEqualizerSensitivity,
                        range: NotchPreferences.equalizerSensitivityRange,
                        step: NotchPreferences.equalizerSensitivityStep,
                        text: String(
                            format: "%.1f×",
                            NotchPreferences.clampedEqualizerSensitivity(equalizerSensitivity)
                        )
                    )
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
        let previewHeight = max(16, compact.height * scale + 14)
        let previewRadius = NotchPreferences.clampedCornerRadius(cornerRadius) * scale

        return VStack(spacing: 8) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 60)

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

            Text("Живой предпросмотр компактного состояния")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
