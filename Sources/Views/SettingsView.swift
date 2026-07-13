import SwiftUI

struct SettingsView: View {
    @AppStorage(PlayerLayout.storageKey)
    private var playerLayoutRawValue = PlayerLayout.fallback.rawValue
    @AppStorage("showAlbumName") private var showsAlbum = true
    @AppStorage("showPlaybackStatus") private var showsPlaybackStatus = true
    @AppStorage("showArtworkShadow") private var showsArtworkShadow = true
    @AppStorage("displayMode") private var selectedModeRawValue = DisplayMode.fallback.rawValue

    private var playerLayout: PlayerLayout {
        PlayerLayout(rawValue: playerLayoutRawValue) ?? .fallback
    }

    private var selectedMode: DisplayMode {
        DisplayMode(rawValue: selectedModeRawValue) ?? .fallback
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                appearanceSection

                Divider()

                displayModeSection
            }
            .padding(24)
        }
        .frame(width: 760, height: 620)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Внешний вид",
                subtitle: "Выберите компоновку popover и второстепенные детали. Изменения применяются сразу."
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Компоновка плеера")
                    .font(.headline)

                HStack(alignment: .top, spacing: 12) {
                    ForEach(PlayerLayout.allCases) { layout in
                        playerLayoutCard(layout)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Показывать название альбома", isOn: $showsAlbum)
                Toggle("Показывать статус Spotify", isOn: $showsPlaybackStatus)
                Toggle("Добавлять тень обложки", isOn: $showsArtworkShadow)
            }
            .toggleStyle(.switch)
            .padding(16)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var displayModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Поверхность приложения",
                subtitle: "Определяет, где TrackPeek показывает текущий трек."
            )

            HStack(alignment: .top, spacing: 12) {
                ForEach(DisplayMode.allCases) { mode in
                    displayModeCard(mode)
                }
            }

            Label(
                "Сейчас доступен Menu Bar. Notch и Floating Widget будут добавлены отдельными этапами.",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
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
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
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
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .padding(12)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
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
