import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general
    case notch
    case widget
    case menuBar
    case shortcuts
    case resources
    case about

    /// Выбранная вкладка хранится в defaults, чтобы контекстное меню могло
    /// открыть настройки сразу на релевантной странице (§20.5).
    static let selectionStorageKey = "settingsSelectedTab"

    var title: String {
        switch self {
        case .resources: String(localized: "Resources")
        case .about: String(localized: "About")
        case .shortcuts:
            String(localized: "Shortcuts")
        case .general:
            String(localized: "General")
        case .notch:
            String(localized: "Notch")
        case .widget:
            String(localized: "Widget")
        case .menuBar:
            String(localized: "Menu Bar")
        }
    }

    var symbolName: String {
        switch self {
        case .resources: "leaf"
        case .about: "info.circle"
        case .shortcuts:
            "keyboard"
        case .general:
            "switch.2"
        case .notch:
            "macbook"
        case .widget:
            "rectangle.on.rectangle"
        case .menuBar:
            "menubar.rectangle"
        }
    }
}

struct SettingsView: View {
    @AppStorage(ResourceUsageMode.storageKey)
    private var resourceUsageModeRaw = ResourceUsageMode.fallback.rawValue
    @AppStorage(OverlayMode.storageKey)
    private var selectedModeRawValue = OverlayMode.fallback.rawValue
    @AppStorage(OverlayVisibilityPolicy.storageKey)
    private var visibilityPolicyRawValue = OverlayVisibilityPolicy.fallback.rawValue
    @AppStorage(MediaSourcePreference.storageKey)
    private var mediaSourceRawValue = MediaSourcePreference.fallback.rawValue
    @AppStorage(SettingsTab.selectionStorageKey)
    private var selectedTabRawValue = SettingsTab.general.rawValue

    @State private var showsResetConfirmation = false
    @State private var presetRevision = 0
    private let onboardingController = OnboardingWindowController()

    private static let resettableKeys: [String] = [
        ResourceUsageMode.storageKey,
        GlobalShortcutsController.bindingsKey,
        GlobalShortcutsController.enabledKey,
        NotchContentLayout.storageKey,
        OverlayMode.storageKey,
        MediaSourcePreference.storageKey,
        "showAlbumName",
        "showPlaybackStatus",
        "showArtworkShadow",
        PopoverBackgroundStyle.storageKey,
        ArtworkSizePreference.storageKey,
        PlayerLayout.storageKey,
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
        NotchPreferences.lyricsEnabledKey,
        WidgetPreferences.positionKey,
        WidgetPreferences.layoutKey,
        WidgetPreferences.edgeOnRightKey,
        WidgetPreferences.freeMoveKey,
        WidgetPreferences.originXKey,
        WidgetPreferences.originTopYKey,
        WidgetPreferences.outlineShimmerKey,
        WidgetPreferences.outlineWidthKey,
        WidgetPreferences.pulseModeKey,
        WidgetPreferences.glassBackgroundKey,
        WidgetPreferences.widthKey,
        WidgetPreferences.displayTargetKey,
        WidgetPreferences.coloredProgressKey,
        WidgetPreferences.coloredWaveformKey,
        WidgetPreferences.colorSourceKey,
        WidgetPreferences.equalizerSensitivityKey,
        WidgetPreferences.lyricsEnabledKey,
        WidgetPreferences.alwaysOnTopKey,
        WidgetPreferences.allSpacesKey,
        WidgetPreferences.hideInFullscreenKey,
        WidgetPreferences.positionLockedKey,
        WidgetPlacementStore.storageKey,
        OverlayVisibilityPolicy.storageKey,
        MenuBarPreferences.controlsEnabledKey,
        MenuBarPreferences.showsTitleKey,
        MenuBarPreferences.showsEqualizerKey,
        MenuBarPreferences.titleWidthKey,
        MenuBarPreferences.spacingKey,
    ]

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var selectedMode: OverlayMode {
        OverlayMode(rawValue: selectedModeRawValue) ?? .fallback
    }

    private var mediaSource: Binding<MediaSourcePreference> {
        Binding(
            get: { MediaSourcePreference(rawValue: mediaSourceRawValue) ?? .fallback },
            set: { mediaSourceRawValue = $0.rawValue }
        )
    }

    private var behaviorPresetSelection: Binding<String> {
        Binding(
            get: {
                _ = presetRevision
                return BehaviorPreset.allCases.first { $0.matches(.standard) }?.rawValue ?? ""
            },
            set: { raw in
                BehaviorPreset(rawValue: raw)?.apply(in: .standard)
                presetRevision += 1
            }
        )
    }

    private var stylePresetSelection: Binding<String> {
        Binding(
            get: {
                _ = presetRevision
                return StylePreset.allCases.first { $0.matches(.standard) }?.rawValue ?? ""
            },
            set: { raw in
                StylePreset(rawValue: raw)?.apply(in: .standard)
                presetRevision += 1
            }
        )
    }

    private var selectedTab: SettingsTab {
        SettingsTab(rawValue: selectedTabRawValue) ?? .general
    }

    var body: some View {
        NavigationSplitView {
            List(selection: Binding<SettingsTab?>(
                get: { selectedTab },
                set: { if let tab = $0 { selectedTabRawValue = tab.rawValue } }
            )) {
                navigationRow(.general)
                Section(String(localized: "Player")) {
                    navigationRow(.notch)
                    navigationRow(.widget)
                    navigationRow(.menuBar)
                }
                Section(String(localized: "Application")) {
                    navigationRow(.shortcuts)
                    navigationRow(.resources)
                    navigationRow(.about)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 185, ideal: 200, max: 215)
        } detail: {
            selectedPage
                .id(selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .navigationTitle(String(localized: "TrackPeek Settings"))
        .frame(width: 940, height: 680)
        .background(SettingsWindowToolbar())
    }

    private func navigationRow(_ tab: SettingsTab) -> some View {
        Label(tab.title, systemImage: tab.symbolName)
            .tag(tab)
            .padding(.vertical, 3)
    }

    @ViewBuilder private var selectedPage: some View {
        switch selectedTab {
        case .general:
            SettingsPage(title: String(localized: "General"), subtitle: String(localized: "Music source, on-screen panel and app startup.")) {
                playbackSection
                LanguageSettingsView()
                launchSection
                presetsSection
            }
        case .notch:
            NotchSettingsView()
        case .widget:
            WidgetSettingsView()
        case .menuBar:
            MenuBarSettingsView()
        case .shortcuts:
            ShortcutSettingsView()
        case .resources:
            SettingsPage(title: String(localized: "Resources and Diagnostics"), subtitle: String(localized: "Energy use, connection and audio capture.")) {
                resourceSection
                PlaybackDiagnosticsView(coordinator: .shared)
            }
        case .about:
            SettingsPage(title: String(localized: "About")) {
                aboutSection
            }
        }
    }

    private var playbackSection: some View {
        SettingsSection(title: String(localized: "Music and Controls")) {
            SettingsGroup {
                SettingsRow(
                    title: String(localized: "Music Source"),
                    subtitle: mediaSource.wrappedValue.summary
                ) {
                    Picker(String(localized: "Music Source"), selection: mediaSource) {
                        ForEach(MediaSourcePreference.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .settingsMenuControl()
                }

                SettingsRowDivider()

                SettingsRow(title: String(localized: "On-Screen Panel"), subtitle: selectedMode.summary) {
                    Picker(String(localized: "On-Screen Panel"), selection: Binding(
                        get: { selectedMode },
                        set: { selectedModeRawValue = $0.rawValue }
                    )) {
                        ForEach(OverlayMode.allCases) { mode in
                            Text(mode == .off ? String(localized: "overlay.off", defaultValue: "Off") : mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 290)
                }

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "When to Show the Panel"),
                    subtitle: String(localized: "For the notch and widget.")
                ) {
                    Picker(String(localized: "settings.showPanel", defaultValue: "Show Panel"), selection: Binding(
                        get: {
                            OverlayVisibilityPolicy(rawValue: visibilityPolicyRawValue) ?? .fallback
                        },
                        set: { visibilityPolicyRawValue = $0.rawValue }
                    )) {
                        ForEach(OverlayVisibilityPolicy.allCases) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                    .settingsMenuControl()
                }
            }

            Text(String(localized: "The menu bar is always available, even when the on-screen panel is off."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var presetsSection: some View {
        SettingsDisclosure(title: String(localized: "Quick Setup"), subtitle: String(localized: "Behavior and appearance presets for the notch and widget.")) {
            SettingsGroup {
                SettingsRow(
                    title: String(localized: "Behavior"),
                    subtitle: String(localized: "Expansion speed and new-track notifications.")
                ) {
                    Picker(String(localized: "Behavior"), selection: behaviorPresetSelection) {
                        Text(String(localized: "Custom")).tag("")
                        ForEach(BehaviorPreset.allCases) { preset in
                            Text(preset.title).tag(preset.rawValue)
                        }
                    }
                    .settingsMenuControl()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Style"),
                    subtitle: String(localized: "Outline, artwork colors and pulse.")
                ) {
                    Picker(String(localized: "Style"), selection: stylePresetSelection) {
                        Text(String(localized: "Custom")).tag("")
                        ForEach(StylePreset.allCases) { preset in
                            Text(preset.title).tag(preset.rawValue)
                        }
                    }
                    .settingsMenuControl()
                }
            }
        }
    }

    private var resourceSection: some View {
        SettingsSection(title: String(localized: "Resources"), subtitle: String(localized: "Your appearance settings are saved and restored when you leave Economical mode.")) {
            SettingsGroup {
                SettingsRow(title: String(localized: "Mode"), subtitle: String(localized: "Automatic follows macOS Low Power Mode, not whether you are on battery power.")) {
                    Picker(String(localized: "Resource Usage Mode"), selection: $resourceUsageModeRaw) {
                        ForEach(ResourceUsageMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .settingsMenuControl()
                }
                SettingsRowDivider()
                SettingsRow(
                    title: PlaybackCoordinator.shared.isSavingResources ? String(localized: "Saving resources") : String(localized: "Normal operation"),
                    subtitle: PlaybackCoordinator.shared.isSavingResources
                        ? String(localized: "Audio capture and decorative animations are off. Progress updates once per second.")
                        : String(localized: "Normal update rate. Effects depend on appearance settings and playback.")
                ) {
                    Image(systemName: PlaybackCoordinator.shared.isSavingResources ? "leaf.fill" : "leaf")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var launchSection: some View {
        SettingsSection(title: String(localized: "Startup")) {
            SettingsGroup {
                LaunchAtLoginToggle()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text("TrackPeek").font(.title3.weight(.semibold))
                    Text(String(localized: "Version \(appVersion)")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(String(localized: "Check for Updates")) {
                    SparkleUpdaterController.shared.checkForUpdates()
                }
            }
            SettingsGroup {
                SettingsRow(title: String(localized: "Initial Setup"), subtitle: String(localized: "Music source, permissions and Open at Login.")) {
                    Button(String(localized: "Open")) { onboardingController.show() }
                }
            }
            SettingsSection(title: String(localized: "settings.reset", defaultValue: "Reset")) {
                SettingsGroup {
                    SettingsRow(title: String(localized: "Restore Default Settings"), subtitle: String(localized: "Appearance, placement and keyboard shortcuts.")) {
                        Button(String(localized: "Reset Settings"), role: .destructive) {
                            showsResetConfirmation = true
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            String(localized: "Reset all TrackPeek settings?"),
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Reset"), role: .destructive) { resetAllSettings() }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Notch, player and display mode settings will return to their defaults."))
        }
    }

    private func resetAllSettings() {
        let defaults = UserDefaults.standard
        for key in Self.resettableKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
