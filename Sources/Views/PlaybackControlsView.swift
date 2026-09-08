import SwiftUI

struct PlaybackControlsView: View {
    let isPlaying: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    var spacing: CGFloat = 16
    /// Уменьшенные кнопки для компактных виджет-раскладок.
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: spacing) {
            control(
                symbol: "backward.fill",
                label: "Предыдущий трек",
                isPrimary: false,
                action: onPrevious
            )

            control(
                symbol: isPlaying ? "pause.fill" : "play.fill",
                label: isPlaying ? "Пауза" : "Воспроизвести",
                isPrimary: true,
                action: {
                    guard !reduceMotion else {
                        onPlayPause()
                        return
                    }

                    withAnimation(
                        .smooth(duration: PlayerMotion.playbackDuration, extraBounce: 0)
                    ) {
                        onPlayPause()
                    }
                }
            )

            control(
                symbol: "forward.fill",
                label: "Следующий трек",
                isPrimary: false,
                action: onNext
            )
        }
    }

    private func control(
        symbol: String,
        label: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        PlaybackControlButton(
            symbol: symbol,
            label: label,
            isPrimary: isPrimary,
            compact: compact,
            action: action
        )
    }
}

struct PlaybackControlButton: View {
    let symbol: String
    let label: String
    let isPrimary: Bool
    var compact = false
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: compact ? (isPrimary ? 12 : 10) : (isPrimary ? 18 : 15), weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .animation(
                    reduceMotion
                        ? nil
                        : .smooth(duration: PlayerMotion.playbackDuration, extraBounce: 0),
                    value: symbol
                )
        }
        .buttonStyle(
            PlaybackControlButtonStyle(
                isPrimary: isPrimary,
                isHovered: isHovered,
                compact: compact
            )
        )
        .onHover { hovering in
            if reduceMotion {
                isHovered = hovering
            } else {
                withAnimation(.easeInOut(duration: PlayerMotion.controlDuration)) {
                    isHovered = hovering
                }
            }
        }
        .help(label)
        .accessibilityLabel(label)
    }
}
