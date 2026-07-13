import SwiftUI

struct StandardPlayerView: View {
    let model: SpotifySpikeModel
    let track: SpotifyTrack
    let options: PlayerPresentationOptions

    var body: some View {
        VStack(spacing: 12) {
            PlayerHeaderView(
                track: track,
                showsPlaybackStatus: options.showsPlaybackStatus,
                onRefresh: model.refresh
            )

            HStack(spacing: 16) {
                TrackArtworkView(
                    url: track.artworkURL,
                    size: 108,
                    cornerRadius: 14,
                    showsShadow: options.showsArtworkShadow
                )

                TrackInfoView(
                    track: track,
                    showsAlbum: options.showsAlbum,
                    titleLineLimit: 2
                )
            }

            VStack(spacing: 6) {
                PlaybackProgressView(
                    position: track.position,
                    duration: track.duration,
                    isPlaying: track.isPlaying,
                    snapshotDate: model.snapshotDate,
                    onSeek: model.seek(to:)
                )

                PlaybackControlsView(
                    isPlaying: track.isPlaying,
                    onPrevious: model.previousTrack,
                    onPlayPause: model.togglePlayback,
                    onNext: model.nextTrack,
                    spacing: 22
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(.primary.opacity(0.07), lineWidth: 1)
            }
        }
        .padding(14)
    }
}
