import SwiftUI

enum SettingsTab: CaseIterable {
    case general
    case notch
    case menuBar
    case player

    var title: String {
        switch self {
        case .general:
            "Основные"
        case .notch:
            "Чёлка"
        case .menuBar:
            "Menu Bar"
        case .player:
            "Плеер"
        }
    }

    var symbolName: String {
        switch self {
        case .general:
            "switch.2"
        case .notch:
            "macbook"
        case .menuBar:
            "menubar.rectangle"
        case .player:
            "play.square"
        }
    }
}

struct SettingsView: View {
    @AppStorage(PlayerLayout.storageKey)
    private var playerLayoutRawValue = PlayerLayout.fallback.rawValue
    @AppStorage("showAlbumName") private var showsAlbum = true
    @AppStorage("showPlaybackStatus") private var showsPlaybackStatus = true
    @AppStorage("showArtworkShadow") private var showsArtworkShadow = true
    @AppStorage(PopoverBackgroundStyle.storageKey)
    private var backgroundStyleRawValue = PopoverBackgroundStyle.fallback.rawValue
    @AppStorage(ArtworkSizePreference.storageKey)
    private var artworkSizeValue = ArtworkSizePreference.fallback
    @AppStorage(DisplayMode.storageKey)
    private var selectedModeRawValue = DisplayMode.fallback.rawValue
    @AppStorage(MediaSourcePreference.storageKey)
    private var mediaSourceRawValue = MediaSourcePreference.fallback.rawValue

    @State private var showsResetConfirmation = false
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled

    private static let resettableKeys: [String] = [
        DisplayMode.storageKey,
        MediaSourcePreference.storageKey,
        "showAlbumName",
        "showPlaybackStatus",
        "showArtworkShadow",
        PopoverBackgroundStyle.storageKey,
        ArtworkSizePreference.storageKey,
        PlayerLayout.storageKey,
        NotchPreferences.enabledKey,
        NotchPreferences.displayTargetKey,
        NotchPreferences.widthKey,
        NotchPreferences.heightAdjustmentKey,
        NotchPreferences.hapticFeedbackKey,
        NotchPreferences.songInfoVisibilityKey,
        NotchPreferences.hoverEnabledKey,
        NotchPreferences.clickEnabledKey,
        NotchPreferences.hoverDelayKey,
        NotchPreferences.notificationsEnabledKey,
        NotchPreferences.notificationDurationKey,
        NotchPreferences.coloredProgressKey,
        NotchPreferences.coloredWaveformKey,
        NotchPreferences.equalizerSensitivityKey,
        NotchPreferences.outlineShimmerKey,
        NotchPreferences.outlineWidthKey,
        NotchPreferences.pulseModeKey,
        NotchPreferences.colorSourceKey,
        NotchPreferences.cornerRadiusKey,
        MenuBarPreferences.controlsEnabledKey,
        MenuBarPreferences.showsTitleKey,
        MenuBarPreferences.showsEqualizerKey,
        MenuBarPreferences.titleWidthKey,
        MenuBarPreferences.spacingKey,
    ]

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var playerLayout: PlayerLayout {
        PlayerLayout(rawValue: playerLayoutRawValue) ?? .fallback
    }

    private var selectedMode: DisplayMode {
        DisplayMode(rawValue: selectedModeRawValue) ?? .fallback
    }

    private var mediaSource: Binding<MediaSourcePreference> {
        Binding(
            get: { MediaSourcePreference(rawValue: mediaSourceRawValue) ?? .fallback },
            set: { mediaSourceRawValue = $0.rawValue }
        )
    }

    private var backgroundStyle: Binding<PopoverBackgroundStyle> {
        Binding(
            get: {
                PopoverBackgroundStyle(rawValue: backgroundStyleRawValue) ?? .fallback
            },
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
        TabView {
            SettingsPage(
                title: "Основные",
                subtitle: "Выберите поверхность TrackPeek и доступный режим отображения."
            ) {
                displayModeSection
                systemSection
                aboutSection
            }
            .tabItem {
                Label(
                    SettingsTab.general.title,
                    systemImage: SettingsTab.general.symbolName
                )
            }

            NotchSettingsView()
                .tabItem {
                    Label(
                        SettingsTab.notch.title,
                        systemImage: SettingsTab.notch.symbolName
                    )
                }

            MenuBarSettingsView()
                .tabItem {
                    Label(
                        SettingsTab.menuBar.title,
                        systemImage: SettingsTab.menuBar.symbolName
                    )
                }

            SettingsPage(
                title: "Плеер",
                subtitle: "Настройте компоновку, обложку и второстепенные детали."
            ) {
                appearanceSection
            }
            .tabItem {
                Label(
                    SettingsTab.player.title,
                    systemImage: SettingsTab.player.symbolName
                )
            }
        }
        .frame(width: 720, height: 640)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: "Popover",
                subtitle: "Компоновка и детали компактного плеера."
            )

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
                    title: "Статус Spotify",
                    subtitle: "Небольшой индикатор воспроизведения или паузы."
                ) {
                    Toggle("Статус Spotify", isOn: $showsPlaybackStatus)
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

    private var displayModeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: "Режим отображения",
                subtitle: "Где TrackPeek будет показывать текущий трек."
            )

            HStack(alignment: .top, spacing: 12) {
                ForEach(DisplayMode.allCases) { mode in
                    displayModeCard(mode)
                }
            }

            Label(
                "Menu Bar и Notch доступны. Floating Widget подключим следующим этапом.",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: "Система",
                subtitle: "Поведение TrackPeek относительно macOS и источник трека."
            )

            SettingsGroup {
                SettingsRow(
                    title: "Запускать при входе в систему",
                    subtitle: "TrackPeek стартует автоматически после входа в macOS."
                ) {
                    Toggle("Запускать при входе в систему", isOn: $launchAtLoginEnabled)
                        .labelsHidden()
                        .onChange(of: launchAtLoginEnabled) { _, enabled in
                            LaunchAtLogin.setEnabled(enabled)
                        }
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Источник трека",
                    subtitle: MediaSourcePreference(rawValue: mediaSourceRawValue)?.summary
                        ?? MediaSourcePreference.fallback.summary
                ) {
                    Picker("Источник трека", selection: mediaSource) {
                        ForEach(MediaSourcePreference.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: "О приложении",
                subtitle: "Версия и сброс настроек до значений по умолчанию."
            )

            HStack(spacing: 14) {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("TrackPeek")
                        .font(.headline)

                    Text("Версия \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Проверить обновления") {
                    SparkleUpdaterController.shared.checkForUpdates()
                }

                Button("Сбросить настройки") {
                    showsResetConfirmation = true
                }
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .confirmationDialog(
            "Сбросить все настройки TrackPeek?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Сбросить", role: .destructive) { resetAllSettings() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Чёлка, плеер и режим отображения вернутся к значениям по умолчанию.")
        }
    }

    private func resetAllSettings() {
        let defaults = UserDefaults.standard
        for key in Self.resettableKeys {
            defaults.removeObject(forKey: key)
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
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        playerLayout == layout ? Color.accentColor : Color.primary.opacity(0.08),
                        lineWidth: playerLayout == layout ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .help("Выбрать \(layout.title)")
        .accessibilityLabel("Компоновка \(layout.title)")
        .accessibilityAddTraits(playerLayout == layout ? .isSelected : [])
    }

    private func displayModeCard(_ mode: DisplayMode) -> some View {
        Button {
            selectedModeRawValue = mode.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 28)
                    .foregroundStyle(mode.isAvailable ? Color.accentColor : Color.secondary)

                HStack {
                    Text(mode.title)
                        .font(.headline)

                    Spacer()

                    if selectedMode == mode {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }

                Text(mode.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Text(mode.isAvailable ? "Доступен" : "В разработке")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(mode.isAvailable ? Color.green : Color.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedMode == mode ? Color.accentColor : Color.primary.opacity(0.07),
                        lineWidth: selectedMode == mode ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!mode.isAvailable)
        .opacity(mode.isAvailable ? 1 : 0.58)
        .help(mode.isAvailable ? "Выбрать \(mode.title)" : "Этот режим пока в разработке")
    }
}
