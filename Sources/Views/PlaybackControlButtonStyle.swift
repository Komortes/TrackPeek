import SwiftUI

struct PlaybackControlButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(
                width: isPrimary ? 48 : 38,
                height: isPrimary ? 48 : 38
            )
            .foregroundStyle(isPrimary ? Color.white : Color.primary)
            .background {
                Circle()
                    .fill(
                        isPrimary
                            ? Color.accentColor
                            : Color.primary.opacity(configuration.isPressed ? 0.13 : 0.07)
                    )
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(isPrimary ? 0.16 : 0.08), lineWidth: 1)
            }
            .shadow(
                color: isPrimary ? Color.accentColor.opacity(0.25) : .clear,
                radius: 8,
                y: 3
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
