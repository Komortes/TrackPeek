import SwiftUI

/// A quiet, fixed-width controller. Metadata lives on the artwork button,
/// leaving the three transport controls available without hovering.
struct WidgetEdgeCard: View {
    let context: WidgetCardContext
    let track: SpotifyTrack
    @State private var showsDetails = false
    @AppStorage(WidgetPreferences.edgeOnRightKey) private var onRight = true

    var body: some View {
        VStack(spacing: 6) {
            Button { showsDetails.toggle() } label: {
                TrackArtworkView(url: track.artworkURL, size: 52, cornerRadius: 12, showsShadow: false)
            }
            .buttonStyle(.plain)
            .help("\(track.title) — \(track.artist)")
            .accessibilityLabel("\(track.title), \(track.artist). Информация о треке")
            .popover(isPresented: $showsDetails, arrowEdge: onRight ? .trailing : .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let album = track.album {
                        Text(album)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 220, alignment: .leading)
                .padding(16)
            }
            .padding(.bottom, 4)

            PlaybackControlButton(symbol: "backward.fill", label: "Предыдущий трек", isPrimary: false) {
                Task { await context.model.previousTrack() }
            }
            PlaybackControlButton(
                symbol: track.isPlaying ? "pause.fill" : "play.fill",
                label: track.isPlaying ? "Пауза" : "Воспроизвести", isPrimary: true
            ) {
                Task { await context.model.togglePlayback() }
            }
            PlaybackControlButton(symbol: "forward.fill", label: "Следующий трек", isPrimary: false) {
                Task { await context.model.nextTrack() }
            }

            TimelineView(.animation(minimumInterval: 1, paused: !track.isPlaying)) { timeline in
                let position = PlaybackPositionResolver.livePosition(
                    snapshotPosition: track.position, snapshotDate: context.model.snapshotDate,
                    now: timeline.date, duration: track.duration, isPlaying: track.isPlaying
                )
                Capsule()
                    .fill(.white.opacity(0.12))
                    .overlay(alignment: .leading) {
                        Capsule().fill(context.progressTint)
                            .frame(width: 38 * (track.duration > 0 ? min(max(position / track.duration, 0), 1) : 0))
                    }
                    .frame(width: 38, height: 2)
                    .accessibilityLabel("Прогресс")
                    .accessibilityValue("\(PlaybackTimeFormatter.string(from: position)) из \(PlaybackTimeFormatter.string(from: track.duration))")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

struct WidgetEdgeUnavailable: View {
    let model: SpotifySpikeModel
    @State private var showsDetails = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
            Button { showsDetails.toggle() } label: {
                Image(systemName: model.availability == .loading ? "ellipsis" : "info.circle")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .help(model.statusText)
            .accessibilityLabel(model.statusText)
            .popover(isPresented: $showsDetails) {
                PlayerStateView(availability: model.availability, sourceName: model.activeSourceDisplayName) {
                    Task { await model.refresh() }
                }
                .frame(width: 240)
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
