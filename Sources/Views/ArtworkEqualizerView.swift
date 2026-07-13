import SwiftUI

struct ArtworkEqualizerView: View {
    let isPlaying: Bool
    let isColored: Bool
    let palette: ArtworkPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barCount = 7

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1 / 18,
                paused: !isPlaying || reduceMotion
            )
        ) { context in
            GeometryReader { proxy in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0 ..< barCount, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(color(for: index))
                            .frame(maxWidth: .infinity)
                            .frame(
                                height: barHeight(
                                    at: index,
                                    date: context.date,
                                    availableHeight: proxy.size.height
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .accessibilityHidden(true)
    }

    private func barHeight(
        at index: Int,
        date: Date,
        availableHeight: CGFloat
    ) -> CGFloat {
        guard isPlaying, !reduceMotion else {
            let restingPattern = [0.22, 0.31, 0.25, 0.36, 0.27, 0.32, 0.23]
            return max(3, availableHeight * restingPattern[index])
        }

        let time = date.timeIntervalSinceReferenceDate
        let phase = time * (2.6 + Double(index % 3) * 0.34) + Double(index) * 0.86
        let secondaryPhase = time * 1.37 + Double(index) * 1.41
        let energy = 0.28
            + abs(sin(phase)) * 0.48
            + abs(cos(secondaryPhase)) * 0.16
        return max(3, availableHeight * min(energy, 0.94))
    }

    private func color(for index: Int) -> Color {
        guard isColored else {
            return .white.opacity(isPlaying ? 0.88 : 0.48)
        }

        return palette.colors[index % palette.colors.count]
            .swiftUIColor
            .opacity(isPlaying ? 0.96 : 0.58)
    }
}

extension ArtworkColor {
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }
}
