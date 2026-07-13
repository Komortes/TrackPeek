import AppKit
import SwiftUI

struct SpotifySpikeView: View {
    @State private var model = SpotifySpikeModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let track = model.track {
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(track.artist)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Label(
                    model.statusText,
                    systemImage: track.isPlaying ? "speaker.wave.2.fill" : "pause.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(
                    "Spotify недоступен",
                    systemImage: "music.note",
                    description: Text(model.statusText)
                )
            }

            HStack {
                Button("Обновить", systemImage: "arrow.clockwise") {
                    model.refresh()
                }

                Spacer()

                if let track = model.track {
                    Button(
                        track.isPlaying ? "Пауза" : "Воспроизвести",
                        systemImage: track.isPlaying ? "pause.fill" : "play.fill"
                    ) {
                        model.togglePlayback()
                    }
                }
            }

            Divider()

            Button("Завершить TrackPeek") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 320)
        .task {
            model.refresh()
        }
    }
}
