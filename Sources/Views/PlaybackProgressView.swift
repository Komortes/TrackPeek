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
    var minimumUpdateInterval: TimeInterval = 1 / 30
    var updatesEnabled = true

    @Environment(\.resourceSaving) private var resourceSaving
    @State private var dragPosition: TimeInterval?
    @State private var isDragging = false
    @State private var isHovering = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canSeek: Bool { duration.isFinite && duration > 0 }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: resourceSaving ? max(1, minimumUpdateInterval) : minimumUpdateInterval,
                paused: !isPlaying || isDragging || !canSeek || !updatesEnabled
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
            .accessibilityLabel(String(localized: "Playback Progress"))
            .accessibilityValue(
                String(localized: "\(PlaybackTimeFormatter.string(from: displayedPosition)) of \(PlaybackTimeFormatter.string(from: duration))")
            )
            .accessibilityHint(String(localized: "Drag or use the left and right arrows to seek"))
            .accessibilityAdjustableAction { direction in
                let step = max(duration * 0.02, 5)
                let offset: TimeInterval

                switch direction {
                case .increment:
                    offset = step
                case .decrement:
                    offset = -step
                @unknown default:
                    return
                }

                if let target = PlaybackPositionResolver.seekPosition(from: displayedPosition, by: offset, duration: duration) {
                    onSeek(target)
                }
            }
        }
    }

    private func scrubber(position: TimeInterval) -> some View {
        GeometryReader { proxy in
            let fraction = duration > 0
                ? min(max(position / duration, 0), 1)
                : 0
            let trackHeight: CGFloat = isHovering || isDragging || isFocused ? 6 : 3

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
                    .opacity(isHovering || isDragging || isFocused ? 1 : 0)
                    .scaleEffect(
                        reduceMotion || isHovering || isDragging || isFocused ? 1 : 0.72
                    )
                    .animation(
                        reduceMotion
                            ? nil
                            : .smooth(duration: PlayerMotion.controlDuration, extraBounce: 0),
                        value: isDragging
                    )
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isFocused = true
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
                if reduceMotion {
                    isHovering = hovering
                } else {
                    withAnimation(.easeInOut(duration: PlayerMotion.controlDuration)) {
                        isHovering = hovering
                    }
                }
            }
            .help(String(localized: "Drag to seek. ←/→ arrows: back/forward 5 seconds."))
        }
        .frame(height: 16)
        .focusable(canSeek, interactions: .edit)
        .focused($isFocused)
        .focusEffectDisabled()
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(tint.opacity(isFocused ? 0.65 : 0), lineWidth: 1)
                .padding(-2)
                .allowsHitTesting(false)
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow], phases: .down) { press in
            guard PlaybackKeyboardInput.accepts(press.modifiers),
                  let target = PlaybackPositionResolver.seekPosition(
                    from: position, by: press.key == .rightArrow ? 5 : -5, duration: duration
                  ) else { return .ignored }
            onSeek(target)
            return .handled
        }
        .allowsHitTesting(canSeek)
    }
}
