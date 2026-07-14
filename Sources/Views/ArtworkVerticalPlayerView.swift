import SwiftUI

struct ArtworkVerticalPlayerView: View {
    let model: SpotifySpikeModel
    let track: SpotifyTrack
    let options: PlayerPresentationOptions
    let artworkSize: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            PlayerHeaderView(
                track: track,
                showsPlaybackStatus: options.showsPlaybackStatus,
                onRefresh: { Task { await model.refresh() } }
            )

            TrackArtworkView(
                url: track.artworkURL,
                size: artworkSize,
                cornerRadius: 17,
                showsShadow: options.showsArtworkShadow
            )

            PlaybackControlsView(
                isPlaying: track.isPlaying,
                onPrevious: { Task { await model.previousTrack() } },
                onPlayPause: { Task { await model.togglePlayback() } },
                onNext: { Task { await model.nextTrack() } },
                spacing: 24
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(.primary.opacity(0.07), lineWidth: 1)
            }

            TrackInfoView(
                track: track,
                showsAlbum: options.showsAlbum,
                titleLineLimit: 2,
                isCentered: true,
                isProminent: true
            )

            PlaybackProgressView(
                position: track.position,
                duration: track.duration,
                isPlaying: track.isPlaying,
                snapshotDate: model.snapshotDate,
                onSeek: { position in Task { await model.seek(to: position) } }
            )
        }
        .padding(14)
    }
}
