import AppKit
import SwiftUI

struct PlayerStateView: View {
    let availability: PlaybackAvailability
    let sourceName: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            stateIcon

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            action
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var stateIcon: some View {
        if availability == .loading {
            ProgressView()
                .controlSize(.small)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var action: some View {
        switch availability {
        case .spotifyNotRunning, .nothingPlaying:
            Button("Открыть \(sourceName)") {
                PlayerAppLauncher.openActiveSource()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .unavailable:
            Button("Повторить", action: onRetry)
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .automationDenied:
            VStack(spacing: 6) {
                Button("Повторить", action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button("Открыть Настройки конфиденциальности") {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        case .loading, .ready:
            EmptyView()
        }
    }

    private var title: String {
        switch availability {
        case .loading:
            "Обновляем трек"
        case .nothingPlaying:
            "Ничего не воспроизводится"
        case .spotifyNotRunning:
            "\(sourceName) не запущен"
        case .automationDenied:
            "Нет доступа к плееру"
        case .unavailable:
            "Не удалось прочитать состояние"
        case .ready:
            ""
        }
    }

    private var message: String {
        switch availability {
        case .loading:
            ""
        case .nothingPlaying:
            "Запустите воспроизведение в \(sourceName)"
        case .spotifyNotRunning:
            "Откройте \(sourceName), чтобы продолжить"
        case .automationDenied:
            "Разрешение Automation отозвано. Включите его для TrackPeek заново."
        case .unavailable:
            "Попробуйте обновить информацию о треке"
        case .ready:
            ""
        }
    }

    private var iconName: String {
        switch availability {
        case .nothingPlaying:
            "music.note"
        case .spotifyNotRunning:
            "music.note.slash"
        case .automationDenied:
            "lock.slash"
        case .unavailable:
            "exclamationmark.triangle"
        case .loading, .ready:
            "music.note"
        }
    }
}
