import SwiftUI

struct PlaybackControlButtonStyle: ButtonStyle {
    let isPrimary: Bool
    var isHovered = false
    var appearance: PlaybackControlsAppearance = .standard

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(
                width: isPrimary ? 38 : 32,
                height: isPrimary ? 38 : 32
            )
            .foregroundStyle(foregroundColor)
            .background {
                Circle()
                    .fill(backgroundColor)
            }
            .overlay {
                Circle()
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(
                color: isPrimary ? .black.opacity(0.14) : .clear,
                radius: 5,
                y: 2
            )
            .scaleEffect(configuration.isPressed ? 0.95 : (isHovered ? 1.04 : 1))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch appearance {
        case .standard:
            isPrimary ? .white : .primary
        case .overArtwork:
            isPrimary ? .black.opacity(0.82) : .white
        }
    }

    private var backgroundColor: Color {
        switch appearance {
        case .standard:
            isPrimary
                ? .accentColor.opacity(isHovered ? 1 : 0.9)
                : .primary.opacity(isHovered ? 0.1 : 0.035)
        case .overArtwork:
            isPrimary
                ? .white.opacity(isHovered ? 1 : 0.92)
                : .white.opacity(isHovered ? 0.18 : 0.07)
        }
    }

    private var borderColor: Color {
        switch appearance {
        case .standard:
            .white.opacity(isPrimary ? 0.16 : 0.08)
        case .overArtwork:
            .white.opacity(isPrimary ? 0.3 : 0.12)
        }
    }
}
