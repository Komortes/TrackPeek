import SwiftUI

struct PlayerHeaderView: View {
    let track: SpotifyTrack?
    let sourceName: String
    let showsPlaybackStatus: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if showsPlaybackStatus {
                PlayerStatusBadge(isPlaying: track?.isPlaying, sourceName: sourceName)
            } else {
                Text("TrackPeek")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PlayerMoreMenu(track: track, sourceName: sourceName, onRefresh: onRefresh)
        }
        .frame(height: 22)
    }
}

struct PlayerStatusBadge: View {
    let isPlaying: Bool?
    let sourceName: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isPlaying == true ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)

            Text(sourceName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sourceName)
        .accessibilityValue(isPlaying.map { $0 ? "Воспроизводится" : "На паузе" } ?? "")
    }
}
