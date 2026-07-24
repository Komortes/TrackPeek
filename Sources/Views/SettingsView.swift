import SwiftUI

enum SettingsTab: CaseIterable {
    case general
    case notch
    case widget
    case menuBar

    var title: String {
        switch self {
        case .general:
            "Основные"
        case .notch:
            "Чёлка"
        case .widget:
            "Виджет"
        case .menuBar:
            "Menu Bar"
        }
    }

    var symbolName: String {
        switch self {
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
    @AppStorage(OverlayMode.storageKey)
    private var selectedModeRawValue = OverlayMode.fallback.rawValue
    @AppStorage(MediaSourcePreference.storageKey)
    private var mediaSourceRawValue = MediaSourcePreference.fallback.rawValue

    @State private var showsResetConfirmation = false
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var automationStatus: AutomationCheckStatus = .unknown
    @State private var automationTask: Task<Void, Never>?
    private let onboardingController = OnboardingWindowController()

    private enum AutomationCheckStatus {
        case unknown, checking, granted, playerNotRunning, failed(String)
    }

    private static let resettableKeys: [String] = [
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

            WidgetSettingsView()
                .tabItem {
                    Label(
                        SettingsTab.widget.title,
                        systemImage: SettingsTab.widget.symbolName
                    )
                }

            MenuBarSettingsView()
                .tabItem {
                    Label(
                        SettingsTab.menuBar.title,
                        systemImage: SettingsTab.menuBar.symbolName
                    )
                }

        }
        .frame(width: 720, height: 640)
    }

    private var displayModeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: "Экранный плеер",
                subtitle: "Menu Bar доступен всегда; здесь выбирается панель поверх рабочего стола."
            )

            HStack(alignment: .top, spacing: 12) {
                ForEach(OverlayMode.allCases) { mode in
                    displayModeCard(mode)
                }
            }

            Label(
                "Иконка и управление в строке меню работают в любом режиме.",
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

                SettingsRowDivider()

                SettingsRow(
                    title: "Доступ к плееру",
                    subtitle: "TrackPeek управляет Spotify/Music через Apple Events."
                ) {
                    HStack(spacing: 8) {
                        Button("Проверить", action: checkAutomationAccess)
                            .disabled(isCheckingAccess)

                        automationStatusView
                    }
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Приветственный экран",
                    subtitle: "Пройти онбординг заново: источник, разрешение, автозапуск."
                ) {
                    Button("Показать") {
                        onboardingController.show()
                    }
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

    private var isCheckingAccess: Bool {
        if case .checking = automationStatus { return true }
        return false
    }

    @ViewBuilder
    private var automationStatusView: some View {
        switch automationStatus {
        case .unknown:
            EmptyView()
        case .checking:
            ProgressView().controlSize(.small)
        case .granted:
            Label("Доступ есть", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .playerNotRunning:
            Label("Плеер не запущен", systemImage: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    private func checkAutomationAccess() {
        automationTask?.cancel()
        automationStatus = .checking
        automationTask = Task { @MainActor in
            do {
                _ = try await PlaybackSourceRouter().fetchCurrentTrack()
                guard !Task.isCancelled else { return }
                automationStatus = .granted
            } catch SpotifyPlaybackError.spotifyNotRunning {
                guard !Task.isCancelled else { return }
                automationStatus = .playerNotRunning
            } catch {
                guard !Task.isCancelled else { return }
                automationStatus = .failed(error.localizedDescription)
            }
        }
    }

    private func resetAllSettings() {
        let defaults = UserDefaults.standard
        for key in Self.resettableKeys {
            defaults.removeObject(forKey: key)
        }
    }

    private func displayModeCard(_ mode: OverlayMode) -> some View {
        Button {
            selectedModeRawValue = mode.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 28)
                    .foregroundStyle(Color.accentColor)

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

                Text(selectedMode == mode ? "Активен" : "Доступен")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selectedMode == mode ? Color.green : Color.secondary)
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
        .help("Выбрать \(mode.title)")
    }
}
