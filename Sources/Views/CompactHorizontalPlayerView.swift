import SwiftUI

struct CompactHorizontalPlayerView: View {
    let model: SpotifySpikeModel
    let track: SpotifyTrack
    let options: PlayerPresentationOptions

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                TrackArtworkView(
                    url: track.artworkURL,
                    size: 112,
                    cornerRadius: 13,
                    showsShadow: options.showsArtworkShadow
                )
                .contentShape(Rectangle())
                .onTapGesture { PlayerAppLauncher.openActiveSource() }
                .help("Открыть плеер")

                if options.showsPlaybackStatus {
                    Circle()
                        .fill(track.isPlaying ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                        .padding(7)
                        .background(.regularMaterial, in: Circle())
                        .padding(7)
                        .help(track.isPlaying ? "Spotify воспроизводит трек" : "Spotify на паузе")
                }
            }

            VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    TrackInfoView(
                        track: track,
                        showsAlbum: false,
                        titleLineLimit: 1
                    )

                    PlayerMoreMenu(
                        track: track,
                        onRefresh: { Task { await model.refresh() } }
                    )
                }

                PlaybackProgressView(
                    position: track.position,
                    duration: track.duration,
                    isPlaying: track.isPlaying,
                    snapshotDate: model.snapshotDate,
                    onSeek: { position in Task { await model.seek(to: position) } },
                    usesCompactTime: true
                )

                PlaybackControlsView(
                    isPlaying: track.isPlaying,
                    onPrevious: { Task { await model.previousTrack() } },
                    onPlayPause: { Task { await model.togglePlayback() } },
                    onNext: { Task { await model.nextTrack() } },
                    spacing: 10
                )
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
