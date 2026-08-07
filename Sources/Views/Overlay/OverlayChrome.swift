import SwiftUI

/// Всё, что раньше называлось «оболочкой» чёлки/виджета: форма-силуэт,
/// фон (включая «стекло» из обложки), пульсация в такт громкости и
/// переливающийся контур. Раньше это было частью тела `NotchPlayerView` и
/// повторно ссылалось на его `@AppStorage`-поля напрямую; теперь это
/// самостоятельный модификатор с явной конфигурацией — контент (чёлка или
/// карточка виджета) ничего не знает об этой отделке.
struct OverlayChromeConfiguration {
    let containerSize: CGSize
    let revealProgress: Double
    let cornerRadius: Double
    let isPillMode: Bool
    let palette: ArtworkPalette
    let pulseMode: NotchPulseMode
    let pulseScale: CGFloat
    let glowOpacity: Double
    let outlineShimmer: Bool
    let outlineWidth: Double
    let shimmerAngle: Angle
    let coloredWaveform: Bool
    let isExpanded: Bool
    let glassBackgroundURL: URL?
    let reduceMotion: Bool
    let reduceTransparency: Bool
}

struct OverlayChrome: ViewModifier {
    let configuration: OverlayChromeConfiguration

    func body(content: Content) -> some View {
        content
            .frame(
                width: configuration.containerSize.width,
                height: configuration.containerSize.height,
                alignment: .top
            )
            .background { background }
            .background { glowLayer }
            .scaleEffect(configuration.pulseScale, anchor: .top)
            .animation(
                configuration.reduceMotion
                    ? nil
                    : .linear(duration: PlayerMotion.spectrumFrameDuration),
                value: configuration.pulseScale
            )
            .clipShape(shape())
            .overlay { outline }
    }

    private func shape(includesTopEdge: Bool? = nil) -> NotchSilhouetteShape {
        let radius = NotchResponsiveLayout.bottomCornerRadius(
            preferredRadius: configuration.cornerRadius,
            revealProgress: configuration.revealProgress,
            height: configuration.containerSize.height
        )
        return NotchSilhouetteShape(
            bottomCornerRadius: radius,
            topCornerRadius: configuration.isPillMode ? radius : 0,
            includesTopEdge: includesTopEdge ?? true
        )
    }

    private var shimmerGradient: AngularGradient {
        AngularGradient(
            colors: [
                configuration.palette.primary.swiftUIColor,
                configuration.palette.secondary.swiftUIColor,
                configuration.palette.tertiary.swiftUIColor,
                configuration.palette.primary.swiftUIColor,
            ],
            center: .center,
            angle: configuration.shimmerAngle
        )
    }

    private var background: some View {
        ZStack {
            Color.black.opacity(0.985)

            if
                configuration.isPillMode,
                configuration.glassBackgroundURL != nil,
                !configuration.reduceTransparency
            {
                // «Стекло»: размытая обложка вместо чёрного фона карточки.
                AsyncImage(url: configuration.glassBackgroundURL) { phase in
                    if case let .success(image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    }
                }
                .blur(radius: 30, opaque: true)
                .overlay(Color.black.opacity(0.45))
            }

            if configuration.coloredWaveform {
                LinearGradient(
                    colors: [
                        configuration.palette.primary.swiftUIColor
                            .opacity(configuration.isExpanded ? 0.20 : 0.12),
                        configuration.palette.secondary.swiftUIColor
                            .opacity(configuration.isExpanded ? 0.10 : 0.04),
                        .clear,
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                .blendMode(.plusLighter)
            }
        }
        .animation(
            configuration.reduceMotion
                ? nil
                : .smooth(duration: PlayerMotion.equalizerDuration, extraBounce: 0),
            value: configuration.palette
        )
    }

    @ViewBuilder
    private var glowLayer: some View {
        if configuration.pulseMode == .glow {
            shape()
                .fill(configuration.palette.primary.swiftUIColor)
                .blur(radius: 10)
                .opacity(configuration.glowOpacity)
                .animation(
                    configuration.reduceMotion
                        ? nil
                        : .linear(duration: PlayerMotion.spectrumFrameDuration),
                    value: configuration.glowOpacity
                )
                .allowsHitTesting(false)
        }
    }

    private var outline: some View {
        ZStack {
            shape(includesTopEdge: configuration.isPillMode)
                .inset(by: 0.5)
                .stroke(Color.white, lineWidth: 1)
                .opacity(
                    NotchResponsiveLayout.baseOutlineOpacity(
                        revealProgress: configuration.revealProgress
                    )
                )
                .allowsHitTesting(false)

            if configuration.outlineShimmer {
                let lineWidth = NotchPreferences.clampedOutlineWidth(configuration.outlineWidth)
                // One full-size silhouette keeps the animated gradient in
                // the same coordinate space across both corners and bottom.
                shape(includesTopEdge: configuration.isPillMode)
                    .inset(by: lineWidth / 2)
                    .stroke(shimmerGradient, lineWidth: lineWidth)
                    .blur(radius: 0.6)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: configuration.containerSize.width, height: configuration.containerSize.height)
        .position(x: configuration.containerSize.width / 2, y: configuration.containerSize.height / 2)
    }
}

extension View {
    func overlayChrome(_ configuration: OverlayChromeConfiguration) -> some View {
        modifier(OverlayChrome(configuration: configuration))
    }
}
