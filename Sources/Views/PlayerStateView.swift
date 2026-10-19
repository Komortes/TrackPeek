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
            Button(String(localized: "Open \(sourceName)")) {
                PlayerAppLauncher.openActiveSource()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .unavailable:
            Button(String(localized: "Retry"), action: onRetry)
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .automationDenied:
            VStack(spacing: 6) {
                Button(String(localized: "Retry"), action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button(String(localized: "Open Privacy & Security Settings")) {
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
            String(localized: "Refreshing track")
        case .nothingPlaying:
            String(localized: "Nothing is playing")
        case .spotifyNotRunning:
            String(localized: "\(sourceName) is not running")
        case .automationDenied:
            String(localized: "No access to the player")
        case .unavailable:
            String(localized: "Could not read player status")
        case .ready:
            ""
        }
    }

    private var message: String {
        switch availability {
        case .loading:
            ""
        case .nothingPlaying:
            String(localized: "Start playback in \(sourceName)")
        case .spotifyNotRunning:
            String(localized: "Open \(sourceName) to continue")
        case .automationDenied:
            String(localized: "Automation permission was revoked. Enable it again for TrackPeek.")
        case .unavailable:
            String(localized: "Try refreshing the track information")
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

/// Appears only during a transient failure; the last snapshot remains readable.
struct PlaybackConnectionBadge: View {
    let model: SpotifySpikeModel
    var compact = false

    var body: some View {
        Button {
            Task { await model.refresh() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                if !compact { Text(String(localized: "Disconnected")) }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.orange)
            .padding(6)
            .background(.black.opacity(0.9), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(model.isRefreshing)
        .help(String(localized: "Showing the last track. Click to check the connection."))
        .accessibilityLabel(String(localized: "Player disconnected. Showing the last track. Check again"))
    }
}
