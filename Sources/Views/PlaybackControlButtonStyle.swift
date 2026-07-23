import SwiftUI

struct PlaybackControlButtonStyle: ButtonStyle {
    let isPrimary: Bool
    var isHovered = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(
                width: isPrimary ? 38 : 32,
                height: isPrimary ? 38 : 32
            )
            .foregroundStyle(isPrimary ? Color.white : Color.primary)
            .background {
                Circle()
                    .fill(
                        isPrimary
                            ? Color.accentColor.opacity(isHovered ? 1 : 0.9)
                            : Color.primary.opacity(isHovered ? 0.1 : 0.035)
                    )
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(isPrimary ? 0.16 : 0.08), lineWidth: 1)
            }
            .shadow(
                color: isPrimary ? .black.opacity(0.14) : .clear,
                radius: 5,
                y: 2
            )
            .scaleEffect(
                reduceMotion
                    ? 1
                    : (configuration.isPressed ? 0.97 : (isHovered ? 1.025 : 1))
            )
            .animation(
                reduceMotion
                    ? nil
                    : .smooth(duration: PlayerMotion.controlDuration, extraBounce: 0),
                value: configuration.isPressed
            )
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: PlayerMotion.controlDuration),
                value: isHovered
            )
    }
}
