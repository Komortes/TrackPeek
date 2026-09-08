import SwiftUI

extension AudioSpectrum: VectorArithmetic {}

private struct EqualizerShape: Shape {
    var spectrum: AudioSpectrum
    /// Число столбиков; при значении больше числа полос спектра значения
    /// линейно интерполируются — волна выглядит детальнее.
    var barCount = AudioSpectrum.bandCount
    /// Позволяет поверхности передать собственную чувствительность вместо
    /// общего notch-значения.
    var sensitivityOverride: Double? = nil

    var animatableData: AudioSpectrum {
        get { spectrum }
        set { spectrum = newValue }
    }

    private func value(at index: Int) -> Double {
        guard barCount != AudioSpectrum.bandCount else { return spectrum[index] }

        let position = Double(index) / Double(max(barCount - 1, 1))
            * Double(AudioSpectrum.bandCount - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, AudioSpectrum.bandCount - 1)
        let fraction = position - Double(lower)
        return spectrum[lower] + (spectrum[upper] - spectrum[lower]) * fraction
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing = min(1, rect.width * 0.018)
        let barWidth = max(
            1,
            (rect.width - spacing * CGFloat(barCount - 1))
                / CGFloat(barCount)
        )

        for index in 0 ..< barCount {
            let height = max(2.5, rect.height * value(at: index))
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
    var barCount = AudioSpectrum.bandCount
    /// Позволяет поверхности передать собственную чувствительность вместо
    /// общего notch-значения.
    var sensitivityOverride: Double? = nil

    @AppStorage(NotchPreferences.equalizerSensitivityKey)
    private var equalizerSensitivity = NotchPreferences.equalizerSensitivityFallback

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var targetSpectrum: AudioSpectrum {
        guard isPlaying, isVisible, !reduceMotion else { return .resting }
        let spectrum = audioMonitor.spectrum

        let sensitivity = NotchPreferences.clampedEqualizerSensitivity(
            sensitivityOverride ?? equalizerSensitivity
        )
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
        EqualizerShape(spectrum: targetSpectrum, barCount: barCount)
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
            .audioSpectrumDemand(audioMonitor, enabled: isPlaying && isVisible && !reduceMotion)
            .accessibilityHidden(true)
    }
}

extension ArtworkColor {
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }
}


private struct AudioSurfaceVisibleKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var audioSurfaceVisible: Bool {
        get { self[AudioSurfaceVisibleKey.self] }
        set { self[AudioSurfaceVisibleKey.self] = newValue }
    }
}

private struct AudioSpectrumDemand: ViewModifier {
    let monitor: SpotifyAudioMonitor
    let enabled: Bool
    @Environment(\.audioSurfaceVisible) private var surfaceVisible
    @State private var consumerID = UUID()

    private var active: Bool { enabled && surfaceVisible }

    func body(content: Content) -> some View {
        content
            .onAppear { monitor.setConsumer(consumerID, active: active) }
            .onChange(of: active) { _, active in monitor.setConsumer(consumerID, active: active) }
            .onDisappear { monitor.setConsumer(consumerID, active: false) }
    }
}

extension View {
    func audioSpectrumDemand(_ monitor: SpotifyAudioMonitor, enabled: Bool) -> some View {
        modifier(AudioSpectrumDemand(monitor: monitor, enabled: enabled))
    }
}
