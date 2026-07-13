import Foundation
import SwiftUI

struct NotchSettingsView: View {
    @AppStorage(DisplayMode.storageKey)
    private var selectedModeRawValue = DisplayMode.fallback.rawValue
    @AppStorage(NotchPreferences.enabledKey)
    private var isEnabled = NotchPreferences.enabledFallback
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

    private var selectedMode: DisplayMode {
        DisplayMode(rawValue: selectedModeRawValue) ?? .fallback
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Чёлка")
                        .font(.title2.weight(.semibold))

                    Text("Компактный плеер у верхнего края экрана, который раскрывается по вашему сценарию.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                activationCard
                generalSection
                interactionSection
                notificationSection
                appearanceSection
            }
            .padding(24)
        }
    }

    private var activationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedMode == .notch ? "checkmark.circle.fill" : "macbook")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selectedMode == .notch ? Color.green : Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedMode == .notch ? "Режим чёлки активен" : "Режим пока не выбран")
                    .font(.headline)

                Text(
                    selectedMode == .notch
                        ? "Панель уже использует настройки ниже."
                        : "Настройки сохранятся; включить панель можно одной кнопкой."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if selectedMode != .notch {
                Button("Использовать чёлку") {
                    selectedModeRawValue = DisplayMode.notch.rawValue
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
        settingsSection(
            title: "Основные",
            subtitle: "Включение, экран и системная обратная связь."
        ) {
            settingsGroup {
                settingRow(
                    title: "Показывать чёлку",
                    subtitle: "Быстро скрывает панель, сохраняя остальные параметры."
                ) {
                    Toggle("Показывать чёлку", isOn: $isEnabled)
                        .labelsHidden()
                }

                rowDivider

                settingRow(
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

                rowDivider

                settingRow(
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
        settingsSection(
            title: "Раскрытие",
            subtitle: "Настройте, как компактная панель превращается в плеер."
        ) {
            settingsGroup {
                settingRow(
                    title: "По наведению",
                    subtitle: "Раскрывать плеер, когда указатель задержался на панели."
                ) {
                    Toggle("По наведению", isOn: $hoverEnabled)
                        .labelsHidden()
                }

                rowDivider

                settingRow(
                    title: "Задержка наведения",
                    subtitle: "Небольшая пауза защищает от случайных раскрытий."
                ) {
                    valueSlider(
                        value: notchHoverDelay,
                        range: NotchPreferences.hoverDelayRange,
                        step: NotchPreferences.hoverDelayStep,
                        text: String(format: "%.2f с", NotchPreferences.clampedHoverDelay(hoverDelay))
                    )
                    .disabled(!hoverEnabled)
                }

                rowDivider

                settingRow(
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
        settingsSection(
            title: "Смена трека",
            subtitle: "Панель может ненадолго раскрыться при начале новой песни."
        ) {
            settingsGroup {
                settingRow(
                    title: "Показывать новый трек",
                    subtitle: "Автоматически раскрывать чёлку при смене композиции."
                ) {
                    Toggle("Показывать новый трек", isOn: $notificationsEnabled)
                        .labelsHidden()
                }

                rowDivider

                settingRow(
                    title: "Длительность",
                    subtitle: "Сколько времени держать уведомление раскрытым."
                ) {
                    valueSlider(
                        value: notchNotificationDuration,
                        range: NotchPreferences.notificationDurationRange,
                        step: NotchPreferences.notificationDurationStep,
                        text: String(
                            format: "%.2f с",
                            NotchPreferences.clampedNotificationDuration(notificationDuration)
                        )
                    )
                    .disabled(!notificationsEnabled)
                }
            }
        }
    }

    private var appearanceSection: some View {
        settingsSection(
            title: "Внешний вид",
            subtitle: "Размеры компактного состояния и акценты плеера."
        ) {
            settingsGroup {
                settingRow(
                    title: "Ширина",
                    subtitle: "Ширина закрытой панели; раскрытая сохраняет пропорции."
                ) {
                    valueSlider(
                        value: notchWidth,
                        range: NotchPreferences.widthRange,
                        step: NotchPreferences.widthStep,
                        text: "\(Int(NotchPreferences.clampedWidth(width))) px"
                    )
                }

                rowDivider

                settingRow(
                    title: "Коррекция высоты",
                    subtitle: "Подстройка под геометрию верхней части экрана."
                ) {
                    valueSlider(
                        value: notchHeightAdjustment,
                        range: NotchPreferences.heightAdjustmentRange,
                        step: NotchPreferences.heightAdjustmentStep,
                        text: String(
                            format: "%+.0f px",
                            NotchPreferences.clampedHeightAdjustment(heightAdjustment)
                        )
                    )
                }

                rowDivider

                settingRow(
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

                rowDivider

                settingRow(
                    title: "Цветной прогресс",
                    subtitle: "Голубой акцент на полосе воспроизведения."
                ) {
                    Toggle("Цветной прогресс", isOn: $coloredProgress)
                        .labelsHidden()
                }

                rowDivider

                settingRow(
                    title: "Цветная волна",
                    subtitle: "Подсвечивать живой индикатор воспроизведения."
                ) {
                    Toggle("Цветная волна", isOn: $coloredWaveform)
                        .labelsHidden()
                }
            }
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
    }

    private func settingsGroup<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
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

    private func settingRow<Control: View>(
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
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

    private var rowDivider: some View {
        Divider().padding(.leading, 14)
    }

    private func valueSlider(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        text: String
    ) -> some View {
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
