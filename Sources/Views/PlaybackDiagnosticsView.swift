import AppKit
import SwiftUI

struct PlaybackDiagnosticsView: View {
    let coordinator: PlaybackCoordinator
    @State private var copied = false

    private var diagnostics: PlaybackDiagnostics {
        PlaybackDiagnostics(
            source: coordinator.model.activeSource,
            availability: coordinator.model.availability,
            isStale: coordinator.model.isStale,
            isSleeping: coordinator.isSleeping,
            lastSuccessfulRefresh: coordinator.model.lastSuccessfulRefresh,
            nextRefreshDate: coordinator.nextRefreshDate,
            audioStatus: coordinator.audioMonitor.analysisStatus
        )
    }

    private var canRetryAudio: Bool {
        switch diagnostics.audioStatus {
        case .failed, .stalled: true
        default: false
        }
    }

    var body: some View {
        SettingsSection(title: String(localized: "Diagnostics"), subtitle: String(localized: "Current connection and audio analysis status.")) {
            SettingsGroup {
                SettingsRow(title: String(localized: "Player"), subtitle: diagnostics.connection) {
                    HStack(spacing: 8) {
                        if coordinator.model.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel(String(localized: "Checking connection"))
                        }
                        Text(diagnostics.source?.displayName ?? String(localized: "Unknown"))
                            .foregroundStyle(.secondary)
                    }
                }
                SettingsRowDivider()
                SettingsRow(title: String(localized: "Player Access"), subtitle: diagnostics.permission) {
                    if diagnostics.availability == .automationDenied {
                        Button(String(localized: "Open Permissions")) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                SettingsRowDivider()
                SettingsRow(title: String(localized: "Audio Analysis"), subtitle: diagnostics.audioStatus.description) {
                    if canRetryAudio {
                        Button(String(localized: "Retry Capture")) { coordinator.audioMonitor.retryIfNeeded() }
                    }
                }
            }
            HStack(spacing: 10) {
                Button(String(localized: "Check Again")) { coordinator.requestRefresh() }
                    .disabled(coordinator.model.isRefreshing || coordinator.isSleeping)
                Button(copied ? String(localized: "Report Copied") : String(localized: "Copy Report")) {
                    let info = Bundle.main.infoDictionary
                    let report = diagnostics.report(
                        version: info?["CFBundleShortVersionString"] as? String ?? "—",
                        build: info?["CFBundleVersion"] as? String ?? "—"
                    )
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.setString(report, forType: .string)
                }
            }
            Text(String(localized: "The report contains only technical status, with no song titles or listening history."))
                .font(.caption)
                .foregroundStyle(.secondary)

            SettingsDisclosure(title: String(localized: "Connection Details"), subtitle: String(localized: "Last response and check schedule.")) {
                SettingsGroup {
                    SettingsRow(title: String(localized: "Last Successful Check"), subtitle: String(localized: "The last player response, including when no track was selected.")) {
                        if let date = diagnostics.lastSuccessfulRefresh {
                            Text(date, format: .dateTime.day().month().hour().minute().second())
                                .font(.caption.monospacedDigit())
                        } else {
                            Text(String(localized: "Not yet")).foregroundStyle(.secondary)
                        }
                    }
                    SettingsRowDivider()
                    SettingsRow(title: String(localized: "Next Check"), subtitle: diagnostics.retryStatus) {
                        if coordinator.model.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else if let date = diagnostics.nextRefreshDate {
                            Text(date, format: .dateTime.hour().minute().second())
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            }
        }
    }
}
