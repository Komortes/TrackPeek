import SwiftUI

struct PlaybackProgressView: View {
    let position: TimeInterval
    let duration: TimeInterval

    var body: some View {
        VStack(spacing: 6) {
            ProgressView(value: clampedPosition, total: progressTotal)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            HStack {
                Text(PlaybackTimeFormatter.string(from: position))

                Spacer()

                Text(PlaybackTimeFormatter.string(from: duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Прогресс воспроизведения")
        .accessibilityValue(
            "\(PlaybackTimeFormatter.string(from: position)) из \(PlaybackTimeFormatter.string(from: duration))"
        )
    }

    private var progressTotal: TimeInterval {
        max(duration, 1)
    }

    private var clampedPosition: TimeInterval {
        min(max(position, 0), progressTotal)
    }
}
