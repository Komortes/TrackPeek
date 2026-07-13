import SwiftUI

struct PlayerHeaderView: View {
    let track: SpotifyTrack?
    let showsPlaybackStatus: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if showsPlaybackStatus {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)

                    Text("Spotify")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("TrackPeek")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PlayerMoreMenu(track: track, onRefresh: onRefresh)
        }
        .frame(height: 22)
    }

    private var statusColor: Color {
        track?.isPlaying == true ? .green : .secondary
    }
}
