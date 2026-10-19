import SwiftUI

struct NotchFocusView: View {
    let model: SpotifySpikeModel
    let state: NotchPanelState
    let size: CGSize
    let topInset: CGFloat
    let cameraWidth: CGFloat
    let isVisible: Bool
    let clickEnabled: Bool
    let onTogglePin: () -> Void
    let onCollapse: () -> Void

    var body: some View {
        Group {
            if let track = model.track {
                switch state {
                case .collapsed:
                    Button { if clickEnabled { onTogglePin() } } label: {
                        HStack(spacing: 0) {
                            Text(track.title).font(.system(size: 10, weight: .medium)).lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if cameraWidth > 0 { Color.clear.frame(width: min(cameraWidth + 16, max(0, size.width - 48))) }
                            Image(systemName: track.isPlaying ? "music.note" : "pause.fill")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                                .frame(maxWidth: cameraWidth > 0 ? .infinity : 24, alignment: .trailing)
                        }
                        .padding(.horizontal, 12).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).help("\(track.title) — \(track.artist)")
                    .accessibilityLabel(String(localized: "\(track.title), \(track.artist). Expand player"))
                case .notification:
                    Text("\(track.title) — \(track.artist)").font(.system(size: 12, weight: .medium))
                        .lineLimit(1).help("\(track.title) — \(track.artist)")
                        .padding(.horizontal, 16).padding(.top, topInset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .expanded:
                    VStack(spacing: 6) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                Text(track.artist).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                                .help("\(track.title) — \(track.artist)")
                            Button(action: onCollapse) { Image(systemName: "chevron.up").frame(width: 24, height: 24) }
                                .buttonStyle(.plain).help(String(localized: "Collapse")).accessibilityLabel(String(localized: "Collapse"))
                        }
                        PlaybackControlsView(isPlaying: track.isPlaying,
                            onPrevious: { Task { await model.previousTrack() } },
                            onPlayPause: { Task { await model.togglePlayback() } },
                            onNext: { Task { await model.nextTrack() } }, spacing: 18, compact: true)
                        PlaybackProgressView(position: track.position, duration: track.duration,
                            isPlaying: track.isPlaying && isVisible && !model.isStale, snapshotDate: model.snapshotDate,
                            onSeek: { position in Task { await model.seek(to: position) } }, tint: .white,
                            minimumUpdateInterval: 0.25)
                    }
                    .padding(.horizontal, 18).padding(.top, max(8, topInset + 4)).padding(.bottom, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if state == .collapsed && cameraWidth > 0 {
                HStack(spacing: 0) {
                    Text(model.statusText).font(.system(size: 10)).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: min(cameraWidth + 16, max(0, size.width - 48)))
                    Image(systemName: "music.note").font(.system(size: 10))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 12).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity).help(model.statusText)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                    Text(model.statusText).lineLimit(state == .expanded ? 2 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if state == .expanded {
                        Button(String(localized: "Retry")) { Task { await model.refresh() } }.buttonStyle(.plain)
                    }
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.top, state == .collapsed ? 0 : topInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}
