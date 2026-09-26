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
        SettingsSection(title: "Диагностика", subtitle: "Текущее подключение и работа аудиоанализа.") {
            SettingsGroup {
                SettingsRow(title: "Плеер", subtitle: diagnostics.connection) {
                    Text(diagnostics.source?.displayName ?? "Не определён")
                        .foregroundStyle(.secondary)
                }
                SettingsRowDivider()
                SettingsRow(title: "Automation", subtitle: diagnostics.permission) {
                    if diagnostics.availability == .automationDenied {
                        Button("Открыть разрешения") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                SettingsRowDivider()
                SettingsRow(title: "Последняя успешная проверка", subtitle: "Последний ответ плеера, включая состояние без трека.") {
                    if let date = diagnostics.lastSuccessfulRefresh {
                        Text(date, format: .dateTime.day().month().hour().minute().second())
                            .font(.caption.monospacedDigit())
                    } else {
                        Text("Ещё не было").foregroundStyle(.secondary)
                    }
                }
                SettingsRowDivider()
                SettingsRow(title: "Следующая проверка", subtitle: diagnostics.retryStatus) {
                    if coordinator.model.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else if let date = diagnostics.nextRefreshDate {
                        Text(date, format: .dateTime.hour().minute().second())
                            .font(.caption.monospacedDigit())
                    }
                }
                SettingsRowDivider()
                SettingsRow(title: "Аудиоанализ", subtitle: diagnostics.audioStatus.description) {
                    if canRetryAudio {
                        Button("Повторить захват") { coordinator.audioMonitor.retryIfNeeded() }
                    }
                }
            }
            HStack(spacing: 10) {
                Button("Проверить снова") { coordinator.requestRefresh() }
                    .disabled(coordinator.model.isRefreshing || coordinator.isSleeping)
                Button(copied ? "Отчёт скопирован" : "Скопировать отчёт") {
                    let info = Bundle.main.infoDictionary
                    let report = diagnostics.report(
                        version: info?["CFBundleShortVersionString"] as? String ?? "—",
                        build: info?["CFBundleVersion"] as? String ?? "—"
                    )
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.setString(report, forType: .string)
                }
            }
            Text("Отчёт содержит только техническое состояние, без названий песен и истории прослушивания.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
