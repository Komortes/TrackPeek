import SwiftUI

struct MenuBarSettingsView: View {
    @AppStorage(MenuBarPreferences.controlsEnabledKey)
    private var controlsEnabled = MenuBarPreferences.controlsEnabledFallback
    @AppStorage(MenuBarPreferences.showsTitleKey)
    private var showsTitle = MenuBarPreferences.showsTitleFallback
    @AppStorage(MenuBarPreferences.showsEqualizerKey)
    private var showsEqualizer = MenuBarPreferences.showsEqualizerFallback
    @AppStorage(MenuBarPreferences.titleWidthKey)
    private var titleWidth = MenuBarPreferences.titleWidthFallback
    @AppStorage(MenuBarPreferences.spacingKey)
    private var spacing = MenuBarPreferences.spacingFallback

    private var menuBarTitleWidth: Binding<Double> {
        Binding(
            get: { MenuBarPreferences.clampedTitleWidth(titleWidth) },
            set: { titleWidth = MenuBarPreferences.clampedTitleWidth($0) }
        )
    }

    private var menuBarSpacing: Binding<Double> {
        Binding(
            get: { MenuBarPreferences.clampedSpacing(spacing) },
            set: { spacing = MenuBarPreferences.clampedSpacing($0) }
        )
    }

    var body: some View {
        SettingsPage(
            title: "Menu Bar",
            subtitle: "Дополнительное управление прямо в строке меню, рядом с иконкой TrackPeek."
        ) {
            activationSection
            appearanceSection
        }
    }

    private var activationSection: some View {
        SettingsSection(
            title: "Основные",
            subtitle: "Popover по-прежнему открывается по клику на лого или название.",
            symbolName: "power"
        ) {
            SettingsGroup {
                SettingsRow(
                    title: "Показывать управление в menu bar",
                    subtitle: "Название трека, анимация звука и кнопки prev/play/next рядом с иконкой."
                ) {
                    Toggle("Показывать управление в menu bar", isOn: $controlsEnabled)
                        .labelsHidden()
                }
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection(
            title: "Внешний вид",
            subtitle: "Как выглядит блок с названием трека в строке меню.",
            symbolName: "textformat"
        ) {
            SettingsGroup {
                SettingsRow(
                    title: "Показывать название",
                    subtitle: "Если выключено, в строке меню остаётся только иконка."
                ) {
                    Toggle("Показывать название", isOn: $showsTitle)
                        .labelsHidden()
                }
                .disabled(!controlsEnabled)

                SettingsRowDivider()

                SettingsRow(
                    title: "Ширина блока названия",
                    subtitle: "Длинные названия обрезаются, чтобы не занимать половину строки меню."
                ) {
                    SettingsValueSlider(
                        value: menuBarTitleWidth,
                        range: MenuBarPreferences.titleWidthRange,
                        step: MenuBarPreferences.titleWidthStep,
                        text: "\(Int(MenuBarPreferences.clampedTitleWidth(titleWidth))) px"
                    )
                }
                .disabled(!controlsEnabled || !showsTitle)

                SettingsRowDivider()

                SettingsRow(
                    title: "Показывать анимацию звука",
                    subtitle: "Мини-эквалайзер рядом с названием."
                ) {
                    Toggle("Показывать анимацию звука", isOn: $showsEqualizer)
                        .labelsHidden()
                }
                .disabled(!controlsEnabled)

                SettingsRowDivider()

                SettingsRow(
                    title: "Отступы",
                    subtitle: "Расстояние между анимацией и названием трека."
                ) {
                    SettingsValueSlider(
                        value: menuBarSpacing,
                        range: MenuBarPreferences.spacingRange,
                        step: MenuBarPreferences.spacingStep,
                        text: "\(Int(MenuBarPreferences.clampedSpacing(spacing))) px"
                    )
                }
                .disabled(!controlsEnabled)
            }
        }
    }
}
