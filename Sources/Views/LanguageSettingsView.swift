import SwiftUI

struct LanguageSettingsView: View {
    private let languageAtLaunch: AppLanguage
    @State private var selectedLanguage: AppLanguage
    @State private var isRestarting = false
    @State private var restartFailed = false

    init() {
        languageAtLaunch = AppLanguage.selectionAtLaunch
        _selectedLanguage = State(initialValue: AppLanguage.selection())
    }

    var body: some View {
        SettingsSection(title: String(localized: "Language")) {
            SettingsGroup {
                SettingsRow(
                    title: String(localized: "App Language"),
                    subtitle: String(localized: "Choose TrackPeek's language independently of macOS.")
                ) {
                    Picker(String(localized: "App Language"), selection: Binding(
                        get: { selectedLanguage },
                        set: { language in
                            language.save()
                            selectedLanguage = language
                            restartFailed = false
                        }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .settingsMenuControl()
                    .disabled(isRestarting)
                }

                if selectedLanguage != languageAtLaunch {
                    SettingsRowDivider()
                    SettingsRow(
                        title: String(localized: "Restart Required"),
                        subtitle: String(localized: "The new language will be used after TrackPeek restarts.")
                    ) {
                        Button(String(localized: "Restart Now")) {
                            isRestarting = true
                            Task { @MainActor in
                                do {
                                    try await ApplicationRelauncher.relaunch()
                                } catch {
                                    restartFailed = true
                                }
                                isRestarting = false
                            }
                        }
                        .disabled(isRestarting)
                    }
                }
            }

            if restartFailed {
                Text(String(localized: "Couldn't restart TrackPeek. Quit and reopen the app to apply the language."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
