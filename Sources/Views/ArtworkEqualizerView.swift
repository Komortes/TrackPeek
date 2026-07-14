import SwiftUI

extension AudioSpectrum: VectorArithmetic {}

private struct EqualizerShape: Shape {
    var spectrum: AudioSpectrum

    var animatableData: AudioSpectrum {
        get { spectrum }
        set { spectrum = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing = min(1, rect.width * 0.018)
        let barWidth = max(
            1,
            (rect.width - spacing * CGFloat(AudioSpectrum.bandCount - 1))
                / CGFloat(AudioSpectrum.bandCount)
        )

        for index in 0 ..< AudioSpectrum.bandCount {
            let height = max(2.5, rect.height * spectrum[index])
            let barRect = CGRect(
                x: CGFloat(index) * (barWidth + spacing),
                y: rect.maxY - height,
                width: barWidth,
                height: height
            )
            path.addRoundedRect(
                in: barRect,
                cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2)
            )
        }

        return path
    }
}

struct ArtworkEqualizerView: View {
    let audioMonitor: SpotifyAudioMonitor
    let isPlaying: Bool
    let isVisible: Bool
    let isColored: Bool
    let palette: ArtworkPalette

    @AppStorage(NotchPreferences.equalizerSensitivityKey)
    private var equalizerSensitivity = NotchPreferences.equalizerSensitivityFallback

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var targetSpectrum: AudioSpectrum {
        guard isPlaying, isVisible, !reduceMotion else { return .resting }
        let spectrum = audioMonitor.spectrum

        let sensitivity = NotchPreferences.clampedEqualizerSensitivity(equalizerSensitivity)
        guard sensitivity != 1 else { return spectrum }

        let scaledValues = (0 ..< AudioSpectrum.bandCount).map { spectrum[$0] * sensitivity }
        return AudioSpectrum(values: scaledValues)
    }

    private var fillStyle: LinearGradient {
        let colors: [Color]
        if isColored {
            colors = palette.colors.map { $0.swiftUIColor.opacity(0.96) }
        } else {
            colors = [.white.opacity(isPlaying ? 0.9 : 0.52)]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        EqualizerShape(spectrum: targetSpectrum)
            .fill(fillStyle)
            .animation(
                reduceMotion
                    ? nil
                    : (isPlaying
                        ? .linear(duration: PlayerMotion.spectrumFrameDuration)
                        : .smooth(duration: PlayerMotion.equalizerDuration, extraBounce: 0)),
                value: targetSpectrum
            )
            .animation(
                reduceMotion
                    ? nil
                    : .smooth(duration: PlayerMotion.equalizerDuration, extraBounce: 0),
                value: palette
            )
            .accessibilityHidden(true)
    }
}

extension ArtworkColor {
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }
}
