import SwiftUI

struct MenuBarSettingsView: View {
    private enum Page: String, CaseIterable {
        case menuBar, player

        var title: String {
            switch self {
            case .menuBar: String(localized: "Indicators and Buttons")
            case .player: String(localized: "Player Window")
            }
        }
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
        SettingsPage(
            title: String(localized: "Menu Bar"),
            subtitle: String(localized: "Indicators and the player window in the menu bar."),
            scrollIdentity: selectedPage.rawValue,
            navigation: {
                Picker(String(localized: "Menu Bar Settings"), selection: $selectedPage) {
                    ForEach(Page.allCases, id: \.self) { page in
                        Text(page.title).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        ) {

            switch selectedPage {
            case .menuBar:
                indicatorPreview
                activationSection
                appearanceSection
            case .player:
                PopoverSettingsSection()
            }
        }
    }

    /// A still, full-size sample: changing appearance never starts an audio
    /// monitor or sends a playback command from the Settings window.
    private var indicatorPreview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("TrackPeek")
                    .font(.system(size: 13, weight: .semibold))

                Spacer(minLength: 20)

                if controlsEnabled {
                    HStack(spacing: 0) {
                        ForEach(["backward.fill", "play.fill", "forward.fill"], id: \.self) { symbol in
                            Image(systemName: symbol)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.trailing, 10)

                    HStack(spacing: MenuBarPreferences.clampedSpacing(spacing)) {
                        if showsEqualizer {
                            Image(systemName: "waveform")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 12)
                        }

                        if showsTitle {
                            Text(String(localized: "Artist and Track"))
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(
                                    maxWidth: MenuBarPreferences.clampedTitleWidth(titleWidth),
                                    alignment: .leading
                                )
                        }
                    }
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 13))
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            Divider()

            Color.clear.frame(height: 28)
        }
        .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        }
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var activationSection: some View {
        SettingsSection(title: String(localized: "Controls")) {
            SettingsGroup {
                SettingsRow(
                    title: String(localized: "Show Controls"),
                    subtitle: String(localized: "Track title and buttons beside the icon.")
                ) {
                    Toggle(String(localized: "Show Controls"), isOn: $controlsEnabled)
                        .labelsHidden()
                }
            }

            Text(String(localized: "Click the icon or track title to open the player."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: String(localized: "Indicators and Spacing")) {
            SettingsGroup {
                SettingsRow(
                    title: String(localized: "Track Title")
                ) {
                    Toggle(String(localized: "Track Title"), isOn: $showsTitle)
                        .labelsHidden()
                }
                .disabled(!controlsEnabled)

                if controlsEnabled, showsTitle {
                    SettingsRowDivider()

                    SettingsRow(
                        title: String(localized: "Title Width"),
                        subtitle: String(localized: "Long titles are truncated.")
                    ) {
                        SettingsValueSlider(
                            label: String(localized: "Title Width"),
                            value: menuBarTitleWidth,
                            range: MenuBarPreferences.titleWidthRange,
                            step: MenuBarPreferences.titleWidthStep,
                            text: String(localized: "\(Int(MenuBarPreferences.clampedTitleWidth(titleWidth))) px")
                        )
                    }
                }

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Audio Animation"),
                    subtitle: String(localized: "An equalizer beside the title.")
                ) {
                    Toggle(String(localized: "Audio Animation"), isOn: $showsEqualizer)
                        .labelsHidden()
                }
                .disabled(!controlsEnabled)

                if controlsEnabled {
                    SettingsRowDivider()

                    SettingsRow(
                        title: String(localized: "Spacing"),
                        subtitle: String(localized: "Between the animation and title.")
                    ) {
                        SettingsValueSlider(
                            label: String(localized: "Spacing"),
                            value: menuBarSpacing,
                            range: MenuBarPreferences.spacingRange,
                            step: MenuBarPreferences.spacingStep,
                            text: String(localized: "\(Int(MenuBarPreferences.clampedSpacing(spacing))) px")
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
        SettingsSection(title: String(localized: "Layout")) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(PlayerLayout.allCases) { layout in
                    playerLayoutCard(layout)
                }
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: String(localized: "settings.appearance", defaultValue: "Appearance")) {
            SettingsGroup {
                SettingsRow(
                    title: String(localized: "Background"),
                    subtitle: playerLayout == .lyrics ? String(localized: "Lyrics use the system background.") : ""
                ) {
                    Picker(String(localized: "Background"), selection: backgroundStyle) {
                        ForEach(PopoverBackgroundStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .settingsMenuControl()
                    .disabled(playerLayout == .lyrics)
                }

                if playerLayout == .artworkVertical {
                    SettingsRowDivider()

                    SettingsRow(title: String(localized: "Artwork Size")) {
                        SettingsValueSlider(
                            label: String(localized: "Artwork Size"),
                            value: artworkSize,
                            range: ArtworkSizePreference.range,
                            step: ArtworkSizePreference.step,
                            text: String(localized: "\(Int(ArtworkSizePreference.clamped(artworkSizeValue))) px")
                        )
                        .accessibilityLabel(String(localized: "Artwork Size"))
                    }
                }

                SettingsRowDivider()

                SettingsRow(title: String(localized: "Album Name")) {
                    Toggle(String(localized: "Album Name"), isOn: $showsAlbum)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(title: String(localized: "Playback Status")) {
                    Toggle(String(localized: "Playback Status"), isOn: $showsPlaybackStatus)
                        .labelsHidden()
                }

                SettingsRowDivider()

                SettingsRow(title: String(localized: "Artwork Shadow")) {
                    Toggle(String(localized: "Artwork Shadow"), isOn: $showsArtworkShadow)
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
            VStack(alignment: .leading, spacing: 7) {
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
                    .lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(10)
            .background(
                playerLayout == layout ? Color.primary.opacity(0.04) : .clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        playerLayout == layout ? Color.accentColor : .clear,
                        lineWidth: 1.5
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(layout.title)
        .accessibilityValue(layout.summary)
        .help(layout.summary)
        .accessibilityAddTraits(playerLayout == layout ? .isSelected : [])
    }
}
