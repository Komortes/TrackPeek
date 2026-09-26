import SwiftUI

struct MenuBarSettingsView: View {
    private enum Page: String, CaseIterable {
        case menuBar = "Строка меню"
        case player = "Окно плеера"
    }

    @State private var selectedPage = Page.menuBar

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
        SettingsPage(title: "Строка меню") {
            Picker("Настройки строки меню", selection: $selectedPage) {
                ForEach(Page.allCases, id: \.self) { page in
                    Text(page.rawValue).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 320)

            switch selectedPage {
            case .menuBar:
                activationSection
                appearanceSection
            case .player:
                PopoverSettingsSection()
            }
        }
    }

    private var activationSection: some View {
        SettingsSection(title: "Управление") {
            SettingsGroup {
                SettingsRow(
                    title: "Показывать управление",
                    subtitle: "Название трека и кнопки рядом с иконкой."
                ) {
                    Toggle("Показывать управление", isOn: $controlsEnabled)
                        .labelsHidden()
                }
            }

            Text("Нажмите на иконку или название трека, чтобы открыть плеер.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: "Индикаторы и интервалы") {
            SettingsGroup {
                SettingsRow(
                    title: "Название трека"
                ) {
                    Toggle("Название трека", isOn: $showsTitle)
                        .labelsHidden()
                }
                .disabled(!controlsEnabled)

                if controlsEnabled, showsTitle {
                    SettingsRowDivider()

                    SettingsRow(
                        title: "Ширина названия",
                        subtitle: "Длинные названия обрезаются."
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
                    title: "Анимация звука",
                    subtitle: "Эквалайзер рядом с названием."
                ) {
                    Toggle("Анимация звука", isOn: $showsEqualizer)
                        .labelsHidden()
                }
                .disabled(!controlsEnabled)

                if controlsEnabled {
                    SettingsRowDivider()

                    SettingsRow(
                        title: "Отступы",
                        subtitle: "Между анимацией и названием."
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


/// Settings for the player opened from the menu bar.
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
        VStack(alignment: .leading, spacing: 24) {
            layoutSection
            appearanceSection
        }
    }

    private var layoutSection: some View {
        SettingsSection(title: "Раскладка") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(PlayerLayout.allCases) { layout in
                    playerLayoutCard(layout)
                }
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: "Внешний вид") {
            SettingsGroup {
                SettingsRow(
                    title: "Фон",
                    subtitle: playerLayout == .lyrics ? "Для текста песни используется системный фон." : ""
                ) {
                    Picker("Фон", selection: backgroundStyle) {
                        ForEach(PopoverBackgroundStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                    .disabled(playerLayout == .lyrics)
                }

                if playerLayout == .artworkVertical {
                    SettingsRowDivider()

                    SettingsRow(title: "Размер обложки") {
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

                SettingsRow(title: "Название альбома") {
                    Toggle("Название альбома", isOn: $showsAlbum)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(title: "Статус воспроизведения") {
                    Toggle("Статус воспроизведения", isOn: $showsPlaybackStatus)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(title: "Тень обложки") {
                    Toggle("Тень обложки", isOn: $showsArtworkShadow)
                        .disabled(playerLayout == .lyrics)
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
