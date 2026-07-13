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
        .frame(width: 340)
        .background(.regularMaterial)
        .task {
            model.refresh()
        }
        .animation(.snappy(duration: 0.24), value: model.track)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tint)

            Text("TrackPeek")
                .font(.caption.weight(.semibold))

            Spacer()

            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r", modifiers: .command)
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
                HStack(alignment: .center, spacing: 14) {
                    artworkPlaceholder

                    VStack(alignment: .leading, spacing: 5) {
                        Text(track.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                            .truncationMode(.tail)

                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        statusBadge(for: track)
                            .padding(.top, 3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    model.togglePlayback()
                } label: {
                    Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .keyboardShortcut(.space, modifiers: [])
                .help(track.isPlaying ? "Поставить на паузу" : "Продолжить воспроизведение")
                .accessibilityLabel(track.isPlaying ? "Пауза" : "Воспроизвести")
            }
            .padding(16)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            unavailableContent
                .padding(20)
                .transition(.opacity)
        }
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.88),
                            Color.accentColor.opacity(0.42),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "music.note")
                .font(.system(size: 29, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: 82, height: 82)
        .shadow(color: Color.accentColor.opacity(0.18), radius: 10, y: 4)
        .accessibilityHidden(true)
    }

    private func statusBadge(for track: SpotifyTrack) -> some View {
        Label(
            model.statusText,
            systemImage: track.isPlaying ? "waveform" : "pause.fill"
        )
        .font(.caption2.weight(.medium))
        .foregroundStyle(track.isPlaying ? Color.green : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
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
            Text("⌘R — обновить")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q", modifiers: .command)
            .help("Завершить TrackPeek")
            .accessibilityLabel("Завершить TrackPeek")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.bar)
    }
}
