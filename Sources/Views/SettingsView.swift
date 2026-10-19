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
        case .resources: "Ресурсы"
        case .about: "О приложении"
        case .shortcuts:
            "Клавиши"
        case .general:
            "Основные"
        case .notch:
            "Чёлка"
        case .widget:
            "Виджет"
        case .menuBar:
            "Строка меню"
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
                Section("Плеер") {
                    navigationRow(.notch)
                    navigationRow(.widget)
                    navigationRow(.menuBar)
                }
                Section("Приложение") {
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
        .navigationTitle("Настройки TrackPeek")
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
            SettingsPage(title: "Основные", subtitle: "Источник музыки, экранная панель и запуск приложения.") {
                playbackSection
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
            SettingsPage(title: "Ресурсы и диагностика", subtitle: "Энергопотребление, подключение и аудиозахват.") {
                resourceSection
                PlaybackDiagnosticsView(coordinator: .shared)
            }
        case .about:
            SettingsPage(title: "О приложении") {
                aboutSection
            }
        }
    }

    private var playbackSection: some View {
        SettingsSection(title: "Музыка и управление") {
            SettingsGroup {
                SettingsRow(
                    title: "Источник музыки",
                    subtitle: mediaSource.wrappedValue.summary
                ) {
                    Picker("Источник музыки", selection: mediaSource) {
                        ForEach(MediaSourcePreference.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .settingsMenuControl()
                }

                SettingsRowDivider()

                SettingsRow(title: "Панель на экране", subtitle: selectedMode.summary) {
                    Picker("Панель на экране", selection: Binding(
                        get: { selectedMode },
                        set: { selectedModeRawValue = $0.rawValue }
                    )) {
                        ForEach(OverlayMode.allCases) { mode in
                            Text(mode == .off ? "Выключена" : mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 290)
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Когда показывать панель",
                    subtitle: "Для чёлки и виджета."
                ) {
                    Picker("Показывать панель", selection: Binding(
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

            Text("Строка меню доступна всегда, даже когда экранная панель выключена.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var presetsSection: some View {
        SettingsDisclosure(title: "Быстрая настройка", subtitle: "Готовые сочетания поведения и оформления чёлки и виджета.") {
            SettingsGroup {
                SettingsRow(
                    title: "Поведение",
                    subtitle: "Скорость раскрытия и уведомления о новых треках."
                ) {
                    Picker("Поведение", selection: behaviorPresetSelection) {
                        Text("Пользовательский").tag("")
                        ForEach(BehaviorPreset.allCases) { preset in
                            Text(preset.title).tag(preset.rawValue)
                        }
                    }
                    .settingsMenuControl()
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Стиль",
                    subtitle: "Контур, цвета обложки и пульсация."
                ) {
                    Picker("Стиль", selection: stylePresetSelection) {
                        Text("Пользовательский").tag("")
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
        SettingsSection(title: "Ресурсы", subtitle: "Оформление сохраняется и возвращается при выходе из экономного режима.") {
            SettingsGroup {
                SettingsRow(title: "Режим", subtitle: "Автоматический следует режиму энергосбережения macOS, а не питанию от батареи.") {
                    Picker("Режим использования ресурсов", selection: $resourceUsageModeRaw) {
                        ForEach(ResourceUsageMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .settingsMenuControl()
                }
                SettingsRowDivider()
                SettingsRow(
                    title: PlaybackCoordinator.shared.isSavingResources ? "Экономия активна" : "Обычная работа",
                    subtitle: PlaybackCoordinator.shared.isSavingResources
                        ? "Аудиозахват и декоративные анимации выключены. Прогресс обновляется раз в секунду."
                        : "Обычная частота обновлений. Эффекты зависят от оформления и воспроизведения."
                ) {
                    Image(systemName: PlaybackCoordinator.shared.isSavingResources ? "leaf.fill" : "leaf")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var launchSection: some View {
        SettingsSection(title: "Запуск") {
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
                    Text("Версия \(appVersion)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Проверить обновления") {
                    SparkleUpdaterController.shared.checkForUpdates()
                }
            }
            SettingsGroup {
                SettingsRow(title: "Первоначальная настройка", subtitle: "Источник музыки, разрешения и автозапуск.") {
                    Button("Открыть") { onboardingController.show() }
                }
            }
            SettingsSection(title: "Сброс") {
                SettingsGroup {
                    SettingsRow(title: "Вернуть настройки по умолчанию", subtitle: "Оформление, расположение и горячие клавиши.") {
                        Button("Сбросить настройки", role: .destructive) {
                            showsResetConfirmation = true
                        }
                    }
                }
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
}
