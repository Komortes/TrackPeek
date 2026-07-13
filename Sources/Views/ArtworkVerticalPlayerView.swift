import SwiftUI

struct ArtworkVerticalPlayerView: View {
    let model: SpotifySpikeModel
    let track: SpotifyTrack
    let options: PlayerPresentationOptions

    var body: some View {
        VStack(spacing: 10) {
            artworkHero

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
                onSeek: model.seek(to:)
            )

        }
        .padding(14)
    }

    private var artworkHero: some View {
        ZStack {
            TrackArtworkView(
                url: track.artworkURL,
                size: 274,
                cornerRadius: 17,
                showsShadow: options.showsArtworkShadow
            )

            VStack {
                HStack {
                    if options.showsPlaybackStatus {
                        PlayerStatusBadge(isPlaying: track.isPlaying)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: Capsule())
                    }

                    Spacer()

                    PlayerMoreMenu(track: track, onRefresh: model.refresh)
                        .padding(4)
                        .background(.regularMaterial, in: Circle())
                }

                Spacer()

                PlaybackControlsView(
                    isPlaying: track.isPlaying,
                    onPrevious: model.previousTrack,
                    onPlayPause: model.togglePlayback,
                    onNext: model.nextTrack,
                    spacing: 20,
                    appearance: .overArtwork
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(.black.opacity(0.46), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }
            }
            .padding(12)
        }
    }
}
