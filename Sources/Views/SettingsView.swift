import SwiftUI

enum SettingsTab: CaseIterable {
    case general
    case notch
    case player

    var title: String {
        switch self {
        case .general:
            "Основные"
        case .notch:
            "Чёлка"
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

    private var playerLayout: PlayerLayout {
        PlayerLayout(rawValue: playerLayoutRawValue) ?? .fallback
    }

    private var selectedMode: DisplayMode {
        DisplayMode(rawValue: selectedModeRawValue) ?? .fallback
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
            settingsPage(
                title: "Основные",
                subtitle: "Выберите поверхность TrackPeek и доступный режим отображения."
            ) {
                displayModeSection
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

            settingsPage(
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

    private func settingsPage<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.semibold))

                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                content()
            }
            .padding(24)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Popover",
                subtitle: "Компоновка и детали компактного плеера."
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(PlayerLayout.allCases) { layout in
                        playerLayoutCard(layout)
                    }
                }
            }

            VStack(spacing: 0) {
                settingRow(
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

                Divider().padding(.leading, 14)

                settingRow(
                    title: "Размер обложки",
                    subtitle: "Масштаб фотографии в режиме Artwork."
                ) {
                    HStack(spacing: 10) {
                        Slider(
                            value: artworkSize,
                            in: ArtworkSizePreference.range,
                            step: ArtworkSizePreference.step
                        )
                        .frame(width: 170)
                        .accessibilityLabel("Размер обложки")

                        Text("\(Int(ArtworkSizePreference.clamped(artworkSizeValue))) px")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                    }
                }

                Divider().padding(.leading, 14)

                settingRow(
                    title: "Название альбома",
                    subtitle: "Показывать дополнительную строку под исполнителем."
                ) {
                    Toggle("Название альбома", isOn: $showsAlbum)
                        .labelsHidden()
                }

                Divider().padding(.leading, 14)

                settingRow(
                    title: "Статус Spotify",
                    subtitle: "Небольшой индикатор воспроизведения или паузы."
                ) {
                    Toggle("Статус Spotify", isOn: $showsPlaybackStatus)
                        .labelsHidden()
                }

                Divider().padding(.leading, 14)

                settingRow(
                    title: "Тень обложки",
                    subtitle: "Добавляет глубину, не меняя саму обложку."
                ) {
                    Toggle("Тень обложки", isOn: $showsArtworkShadow)
                        .labelsHidden()
                }
            }
            .toggleStyle(.switch)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var displayModeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
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

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
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

            Spacer(minLength: 20)

            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
