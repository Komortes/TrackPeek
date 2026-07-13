import SwiftUI

struct StandardPlayerView: View {
    let model: SpotifySpikeModel
    let track: SpotifyTrack
    let options: PlayerPresentationOptions

    var body: some View {
        VStack(spacing: 14) {
            PlayerHeaderView(
                track: track,
                showsPlaybackStatus: options.showsPlaybackStatus,
                onRefresh: model.refresh
            )

            HStack(spacing: 14) {
                TrackArtworkView(
                    url: track.artworkURL,
                    size: 94,
                    cornerRadius: 12,
                    showsShadow: options.showsArtworkShadow
                )

                TrackInfoView(
                    track: track,
                    showsAlbum: options.showsAlbum,
                    titleLineLimit: 2
                )
            }

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
                onNext: model.nextTrack
            )
        }
        .padding(16)
    }
}
