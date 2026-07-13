import AppKit
import SwiftUI

struct PlaybackProgressView: View {
    let position: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    let snapshotDate: Date
    let onSeek: (TimeInterval) -> Void
    var usesCompactTime = false
    var tint: Color = .accentColor

    @State private var dragPosition: TimeInterval?
    @State private var isDragging = false
    @State private var isHovering = false

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1 / 30,
                paused: !isPlaying || isDragging
            )
        ) { context in
            let displayedPosition = dragPosition ?? PlaybackPositionResolver.livePosition(
                snapshotPosition: position,
                snapshotDate: snapshotDate,
                now: context.date,
                duration: duration,
                isPlaying: isPlaying
            )

            VStack(spacing: 5) {
                scrubber(position: displayedPosition)

                if usesCompactTime {
                    Text(
                        "\(PlaybackTimeFormatter.string(from: displayedPosition)) / \(PlaybackTimeFormatter.string(from: duration))"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack {
                        Text(PlaybackTimeFormatter.string(from: displayedPosition))

                        Spacer()

                        Text(PlaybackTimeFormatter.string(from: duration))
                    }
                }
            }
            .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Прогресс воспроизведения")
            .accessibilityValue(
                "\(PlaybackTimeFormatter.string(from: displayedPosition)) из \(PlaybackTimeFormatter.string(from: duration))"
            )
            .accessibilityHint("Перетащите или измените значение для перемотки")
            .accessibilityAdjustableAction { direction in
                let step = max(duration * 0.02, 5)
                let target: TimeInterval

                switch direction {
                case .increment:
                    target = min(displayedPosition + step, duration)
                case .decrement:
                    target = max(displayedPosition - step, 0)
                @unknown default:
                    return
                }

                onSeek(target)
            }
        }
    }

    private func scrubber(position: TimeInterval) -> some View {
        GeometryReader { proxy in
            let fraction = duration > 0
                ? min(max(position / duration, 0), 1)
                : 0
            let trackHeight: CGFloat = isHovering || isDragging ? 6 : 3

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: trackHeight)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: trackHeight)
                    .scaleEffect(x: fraction, anchor: .leading)

                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle()
                            .stroke(tint.opacity(0.3), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                    .offset(x: max((proxy.size.width - 10) * fraction, 0))
                    .opacity(isHovering || isDragging ? 1 : 0)
                    .scaleEffect(isHovering || isDragging ? 1 : 0.72)
                    .animation(.easeOut(duration: 0.12), value: isDragging)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragPosition = PlaybackPositionResolver.position(
                            at: value.location.x,
                            width: proxy.size.width,
                            duration: duration
                        )
                    }
                    .onEnded { value in
                        let target = PlaybackPositionResolver.position(
                            at: value.location.x,
                            width: proxy.size.width,
                            duration: duration
                        )
                        onSeek(target)
                        dragPosition = nil
                        isDragging = false
                    }
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isHovering = hovering
                }
            }
            .help("Перетащите для перемотки")
        }
        .frame(height: 16)
        .allowsHitTesting(duration > 0)
    }
}
