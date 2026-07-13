import AppKit
import SwiftUI

struct SpotifySpikeView: View {
    @State private var model = SpotifySpikeModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content

            Divider()

            footer
        }
        .frame(width: 360)
        .background(.regularMaterial)
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

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tint)

            Text("TrackPeek")
                .font(.caption.weight(.semibold))

            Spacer()

            if let track = model.track {
                HStack(spacing: 5) {
                    Circle()
                        .fill(track.isPlaying ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)

                    Text(model.statusText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.18), value: track.isPlaying)
            }

            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Обновить текущий трек")
            .accessibilityLabel("Обновить текущий трек")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let track = model.track {
            VStack(spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    TrackArtworkView(url: track.artworkURL)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .contentTransition(.opacity)

                        Text(track.artist)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .contentTransition(.opacity)

                        if let album = track.album {
                            Text(album)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .contentTransition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                PlaybackProgressView(
                    position: track.position,
                    duration: track.duration,
                    isPlaying: track.isPlaying,
                    snapshotDate: model.snapshotDate,
                    onSeek: model.seek(to:)
                )

                playbackControls(for: track)
            }
            .padding(18)
            .animation(.easeOut(duration: 0.2), value: trackIdentity(track))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            unavailableContent
                .padding(20)
                .transition(.opacity)
        }
    }

    private func playbackControls(for track: SpotifyTrack) -> some View {
        HStack(spacing: 18) {
            Button {
                model.previousTrack()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(PlaybackControlButtonStyle(isPrimary: false))
            .help("Предыдущий трек")
            .accessibilityLabel("Предыдущий трек")

            Button {
                model.togglePlayback()
            } label: {
                Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .contentTransition(.opacity)
            }
            .buttonStyle(PlaybackControlButtonStyle(isPrimary: true))
            .animation(.easeOut(duration: 0.16), value: track.isPlaying)
            .help(track.isPlaying ? "Поставить на паузу" : "Продолжить воспроизведение")
            .accessibilityLabel(track.isPlaying ? "Пауза" : "Воспроизвести")

            Button {
                model.nextTrack()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(PlaybackControlButtonStyle(isPrimary: false))
            .help("Следующий трек")
            .accessibilityLabel("Следующий трек")
        }
        .frame(maxWidth: .infinity)
    }

    private func trackIdentity(_ track: SpotifyTrack) -> String {
        "\(track.title)|\(track.artist)|\(track.album ?? "")"
    }

    private var unavailableContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.slash")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 58, height: 58)
                .background(.quaternary, in: Circle())

            VStack(spacing: 4) {
                Text("Spotify недоступен")
                    .font(.headline)

                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Button("Попробовать снова", systemImage: "arrow.clockwise") {
                model.refresh()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Настройки TrackPeek")
            .accessibilityLabel("Открыть настройки TrackPeek")

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Завершить TrackPeek")
            .accessibilityLabel("Завершить TrackPeek")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.bar)
    }
}
