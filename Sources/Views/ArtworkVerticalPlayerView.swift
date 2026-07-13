import SwiftUI

struct ArtworkVerticalPlayerView: View {
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

            TrackArtworkView(
                url: track.artworkURL,
                size: 240,
                cornerRadius: 14,
                showsShadow: options.showsArtworkShadow
            )

            TrackInfoView(
                track: track,
                showsAlbum: options.showsAlbum,
                titleLineLimit: 2
            )

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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
