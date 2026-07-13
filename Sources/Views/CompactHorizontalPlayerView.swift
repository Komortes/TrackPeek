import SwiftUI

struct CompactHorizontalPlayerView: View {
    let model: SpotifySpikeModel
    let track: SpotifyTrack
    let options: PlayerPresentationOptions

    var body: some View {
        VStack(spacing: 8) {
            PlayerHeaderView(
                track: track,
                showsPlaybackStatus: options.showsPlaybackStatus,
                onRefresh: model.refresh
            )

            HStack(spacing: 12) {
                TrackArtworkView(
                    url: track.artworkURL,
                    size: 82,
                    cornerRadius: 11,
                    showsShadow: options.showsArtworkShadow
                )

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TrackInfoView(
                            track: track,
                            showsAlbum: false,
                            titleLineLimit: 1
                        )

                        PlaybackControlsView(
                            isPlaying: track.isPlaying,
                            onPrevious: model.previousTrack,
                            onPlayPause: model.togglePlayback,
                            onNext: model.nextTrack,
                            spacing: 6
                        )
                        .fixedSize()
                    }

                    PlaybackProgressView(
                        position: track.position,
                        duration: track.duration,
                        isPlaying: track.isPlaying,
                        snapshotDate: model.snapshotDate,
                        onSeek: model.seek(to:),
                        usesCompactTime: true
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
