import AppKit
import SwiftUI

struct TrackPeekPopoverView: View {
    private let model = PlaybackCoordinator.shared.model

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
        .playerContextMenu(track: model.track, sourceName: model.activeSourceDisplayName, onRefresh: requestRefresh)
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
            // Опрос ведёт PlaybackCoordinator; при открытии popover просто
            // подтягиваем свежий снапшот без задержки.
            await model.refresh()
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
                sourceName: model.activeSourceDisplayName,
                showsPlaybackStatus: showsPlaybackStatus,
                onRefresh: requestRefresh
            )

            PlayerStateView(
                availability: model.availability,
                sourceName: model.activeSourceDisplayName,
                onRetry: requestRefresh
            )
        }
        .padding(playerLayout == .artworkVertical ? 20 : 14)
    }

    private func requestRefresh() {
        Task { await model.refresh() }
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
