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
            subtitle: "Строка меню и окно плеера, которое открывается из неё."
        ) {
            activationSection
            appearanceSection
            PopoverSettingsSection()
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

                if controlsEnabled, showsTitle {
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
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Показывать анимацию звука",
                    subtitle: "Мини-эквалайзер рядом с названием."
                ) {
                    Toggle("Показывать анимацию звука", isOn: $showsEqualizer)
                        .labelsHidden()
                }
                .disabled(!controlsEnabled)

                if controlsEnabled {
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
                }
            }
        }
    }
}


/// Настройки окна плеера (popover). Живут на вкладке Menu Bar, потому что
/// popover открывается именно из строки меню.
struct PopoverSettingsSection: View {
    @AppStorage(PlayerLayout.storageKey)
    private var playerLayoutRawValue = PlayerLayout.fallback.rawValue
    @AppStorage("showAlbumName") private var showsAlbum = true
    @AppStorage("showPlaybackStatus") private var showsPlaybackStatus = true
    @AppStorage("showArtworkShadow") private var showsArtworkShadow = true
    @AppStorage(PopoverBackgroundStyle.storageKey)
    private var backgroundStyleRawValue = PopoverBackgroundStyle.fallback.rawValue
    @AppStorage(ArtworkSizePreference.storageKey)
    private var artworkSizeValue = ArtworkSizePreference.fallback

    private var playerLayout: PlayerLayout {
        PlayerLayout(rawValue: playerLayoutRawValue) ?? .fallback
    }

    private var backgroundStyle: Binding<PopoverBackgroundStyle> {
        Binding(
            get: { PopoverBackgroundStyle(rawValue: backgroundStyleRawValue) ?? .fallback },
            set: { backgroundStyleRawValue = $0.rawValue }
        )
    }

    private var artworkSize: Binding<Double> {
        Binding(
            get: { ArtworkSizePreference.clamped(artworkSizeValue) },
            set: { artworkSizeValue = ArtworkSizePreference.clamped($0) }
        )
    }

    var body: some View {
        SettingsSection(
            title: "Окно плеера",
            subtitle: "Компоновка и детали popover, открывающегося по клику.",
            symbolName: "play.square"
        ) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(PlayerLayout.allCases) { layout in
                    playerLayoutCard(layout)
                }
            }

            SettingsGroup {
                SettingsRow(
                    title: "Фон",
                    subtitle: "Системный материал или цвета текущей обложки."
                ) {
                    Picker("Фон", selection: backgroundStyle) {
                        ForEach(PopoverBackgroundStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                if playerLayout == .artworkVertical {
                    SettingsRowDivider()

                    SettingsRow(
                        title: "Размер обложки",
                        subtitle: "Масштаб фотографии в режиме Artwork."
                    ) {
                        SettingsValueSlider(
                            value: artworkSize,
                            range: ArtworkSizePreference.range,
                            step: ArtworkSizePreference.step,
                            text: "\(Int(ArtworkSizePreference.clamped(artworkSizeValue))) px"
                        )
                        .accessibilityLabel("Размер обложки")
                    }
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Название альбома",
                    subtitle: "Показывать дополнительную строку под исполнителем."
                ) {
                    Toggle("Название альбома", isOn: $showsAlbum)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Статус воспроизведения",
                    subtitle: "Небольшой индикатор воспроизведения или паузы."
                ) {
                    Toggle("Статус воспроизведения", isOn: $showsPlaybackStatus)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Тень обложки",
                    subtitle: "Добавляет глубину, не меняя саму обложку."
                ) {
                    Toggle("Тень обложки", isOn: $showsArtworkShadow)
                        .labelsHidden()
                }
            }
        }
    }

    private func playerLayoutCard(_ layout: PlayerLayout) -> some View {
        Button {
            playerLayoutRawValue = layout.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                PlayerLayoutPreview(layout: layout)

                HStack {
                    Text(layout.title)
                        .font(.headline)

                    Spacer()

                    if playerLayout == layout {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }

                Text(layout.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        playerLayout == layout ? Color.accentColor : Color.primary.opacity(0.07),
                        lineWidth: playerLayout == layout ? 2 : 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(layout.title)
        .accessibilityAddTraits(playerLayout == layout ? .isSelected : [])
    }
}
