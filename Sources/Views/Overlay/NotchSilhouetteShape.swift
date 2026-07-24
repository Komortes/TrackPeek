import SwiftUI

/// Силуэт чёлки/виджета: скруглены только нижние углы (чёлка, прижатая к
/// кромке экрана) либо все четыре (пилюля floating-виджета, когда
/// `topCornerRadius > 0`).
struct NotchSilhouetteShape: InsettableShape {
    var bottomCornerRadius: CGFloat
    var topCornerRadius: CGFloat
    private var insetAmount: CGFloat
    private let includesTopEdge: Bool

    init(
        bottomCornerRadius: CGFloat,
        topCornerRadius: CGFloat = 0,
        insetAmount: CGFloat = 0,
        includesTopEdge: Bool = true
    ) {
        self.bottomCornerRadius = bottomCornerRadius
        self.topCornerRadius = topCornerRadius
        self.insetAmount = insetAmount
        self.includesTopEdge = includesTopEdge
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomCornerRadius, insetAmount) }
        set {
            bottomCornerRadius = newValue.first
            insetAmount = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let frame = rect.insetBy(dx: insetAmount, dy: insetAmount)

        guard frame.width > 0, frame.height > 0 else {
            return Path()
        }

        let radius = min(
            max(bottomCornerRadius - insetAmount, 0),
            min(frame.width, frame.height) / 2
        )

        let topLeading = CGPoint(x: frame.minX, y: frame.minY)
        let topTrailing = CGPoint(x: frame.maxX, y: frame.minY)
        let bottomTrailing = CGPoint(x: frame.maxX, y: frame.maxY)
        let bottomLeading = CGPoint(x: frame.minX, y: frame.maxY)

        var path = Path()

        let topRadius = min(
            max(topCornerRadius - insetAmount, 0),
            min(frame.width, frame.height) / 2
        )

        if includesTopEdge, topRadius > 0 {
            path.move(to: CGPoint(x: frame.minX + topRadius, y: frame.minY))
            path.addLine(to: CGPoint(x: frame.maxX - topRadius, y: frame.minY))
            path.addArc(
                tangent1End: topTrailing,
                tangent2End: bottomTrailing,
                radius: topRadius
            )

            if radius > 0 {
                path.addArc(
                    tangent1End: bottomTrailing,
                    tangent2End: bottomLeading,
                    radius: radius
                )
                path.addArc(
                    tangent1End: bottomLeading,
                    tangent2End: topLeading,
                    radius: radius
                )
            } else {
                path.addLine(to: bottomTrailing)
                path.addLine(to: bottomLeading)
            }

            path.addArc(
                tangent1End: topLeading,
                tangent2End: topTrailing,
                radius: topRadius
            )
            path.closeSubpath()
            return path
        }

        if includesTopEdge {
            path.move(to: topLeading)
            path.addLine(to: topTrailing)

            if radius > 0 {
                path.addArc(
                    tangent1End: bottomTrailing,
                    tangent2End: bottomLeading,
                    radius: radius
                )
                path.addArc(
                    tangent1End: bottomLeading,
                    tangent2End: topLeading,
                    radius: radius
                )
            } else {
                path.addLine(to: bottomTrailing)
                path.addLine(to: bottomLeading)
            }

            path.closeSubpath()
        } else {
            path.move(to: topLeading)

            if radius > 0 {
                path.addArc(
                    tangent1End: bottomLeading,
                    tangent2End: bottomTrailing,
                    radius: radius
                )
                path.addArc(
                    tangent1End: bottomTrailing,
                    tangent2End: topTrailing,
                    radius: radius
                )
            } else {
                path.addLine(to: bottomLeading)
                path.addLine(to: bottomTrailing)
            }

            path.addLine(to: topTrailing)
        }

        return path
    }

    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}
