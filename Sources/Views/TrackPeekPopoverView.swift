import AppKit
import SwiftUI

struct TrackPeekPopoverView: View {
    @State private var model = SpotifySpikeModel()

    @AppStorage(PlayerLayout.storageKey)
    private var playerLayoutRawValue = PlayerLayout.fallback.rawValue
    @AppStorage("showAlbumName") private var showsAlbum = true
    @AppStorage("showPlaybackStatus") private var showsPlaybackStatus = true
    @AppStorage("showArtworkShadow") private var showsArtworkShadow = true
    @AppStorage(PopoverBackgroundStyle.storageKey)
    private var backgroundStyleRawValue = PopoverBackgroundStyle.fallback.rawValue
    @AppStorage(ArtworkSizePreference.storageKey)
    private var artworkSizeValue = ArtworkSizePreference.fallback

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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

    private var backgroundStyle: PopoverBackgroundStyle {
        PopoverBackgroundStyle(rawValue: backgroundStyleRawValue) ?? .fallback
    }

    private var artworkSize: Double {
        ArtworkSizePreference.clamped(artworkSizeValue)
    }

    private var popoverSize: CGSize {
        playerLayout.popoverSize(artworkSize: artworkSize)
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
            width: popoverSize.width,
            height: popoverSize.height
        )
        .background {
            PopoverBackground(
                style: reduceTransparency ? .systemMaterial : backgroundStyle,
                artworkURL: model.track?.artworkURL
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: model.track?.title
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.22),
            value: playerLayout
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: artworkSize
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
            ArtworkVerticalPlayerView(
                model: model,
                track: track,
                options: options,
                artworkSize: CGFloat(artworkSize)
            )
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

private struct PopoverBackground: View {
    let style: PopoverBackgroundStyle
    let artworkURL: URL?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            if style == .artworkBlur, let artworkURL {
                AsyncImage(
                    url: artworkURL,
                    transaction: Transaction(
                        animation: reduceMotion ? nil : .easeInOut(duration: 0.28)
                    )
                ) { phase in
                    if case let .success(image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 34)
                            .scaleEffect(1.2)
                            .transition(.opacity)
                    }
                }

                Rectangle()
                    .fill(.thinMaterial)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
