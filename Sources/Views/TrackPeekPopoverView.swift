import AppKit
import SwiftUI

struct TrackPeekPopoverView: View {
    @State private var model = SpotifySpikeModel()

    @AppStorage(PlayerLayout.storageKey)
    private var playerLayoutRawValue = PlayerLayout.fallback.rawValue
    @AppStorage("showAlbumName") private var showsAlbum = true
    @AppStorage("showPlaybackStatus") private var showsPlaybackStatus = true
    @AppStorage("showArtworkShadow") private var showsArtworkShadow = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var playerLayout: PlayerLayout {
        PlayerLayout(rawValue: playerLayoutRawValue) ?? .fallback
    }

    private var options: PlayerPresentationOptions {
        PlayerPresentationOptions(
            showsAlbum: showsAlbum,
            showsPlaybackStatus: showsPlaybackStatus,
            showsArtworkShadow: showsArtworkShadow
        )
    }

    var body: some View {
        Group {
            if let track = model.track, model.availability == .ready {
                player(track)
                    .transition(.opacity)
            } else {
                unavailableContent
                    .transition(.opacity)
            }
        }
        .frame(
            width: playerLayout.popoverSize.width,
            height: playerLayout.popoverSize.height
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: model.track?.title
        )
        .task {
            while !Task.isCancelled {
                model.refresh()

                let interval = model.track?.isPlaying == true
                    ? Duration.seconds(2)
                    : Duration.seconds(4)
                try? await Task.sleep(for: interval)
            }
        }
    }

    @ViewBuilder
    private func player(_ track: SpotifyTrack) -> some View {
        switch playerLayout {
        case .compactHorizontal:
            CompactHorizontalPlayerView(model: model, track: track, options: options)
        case .standard:
            StandardPlayerView(model: model, track: track, options: options)
        case .artworkVertical:
            ArtworkVerticalPlayerView(model: model, track: track, options: options)
        }
    }

    private var unavailableContent: some View {
        VStack(spacing: 8) {
            PlayerHeaderView(
                track: nil,
                showsPlaybackStatus: showsPlaybackStatus,
                onRefresh: model.refresh
            )

            PlayerStateView(
                availability: model.availability,
                onRetry: model.refresh
            )
        }
        .padding(playerLayout == .artworkVertical ? 20 : 14)
    }
}
