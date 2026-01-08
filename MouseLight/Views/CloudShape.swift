import SwiftUI

/// Cloud shape for spotlight effect
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        // SVG cloud bounds (approximate)
        let svgMinX: CGFloat = 260.0
        let svgMinY: CGFloat = 210.0
        let svgWidth: CGFloat = 272.0
        let svgHeight: CGFloat = 191.0

        // Scale and translate to fit the target rect
        let scaleX = rect.width / svgWidth
        let scaleY = rect.height / svgHeight
        let scale = min(scaleX, scaleY)

        let offsetX = rect.minX + (rect.width - svgWidth * scale) / 2 - svgMinX * scale
        let offsetY = rect.minY + (rect.height - svgHeight * scale) / 2 - svgMinY * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scale + offsetX, y: y * scale + offsetY)
        }

        var path = Path()

        path.move(to: point(373.3, 231.2))

        path.addCurve(
            to: point(407.8, 216.4),
            control1: point(382.1, 222.1),
            control2: point(394.3, 216.4)
        )

        path.addCurve(
            to: point(449.8, 241.3),
            control1: point(425.8, 216.4),
            control2: point(441.4, 226.4)
        )

        path.addCurve(
            to: point(473.5, 236.3),
            control1: point(457.1, 238.1),
            control2: point(465.1, 236.3)
        )

        path.addCurve(
            to: point(532.2, 295.5),
            control1: point(505.9, 236.3),
            control2: point(532.2, 262.8)
        )

        path.addCurve(
            to: point(473.5, 354.7),
            control1: point(532.2, 328.2),
            control2: point(505.9, 354.7)
        )

        path.addCurve(
            to: point(461.9, 353.5),
            control1: point(469.5, 354.7),
            control2: point(465.7, 354.3)
        )

        path.addCurve(
            to: point(424.5, 375.5),
            control1: point(454.6, 366.6),
            control2: point(440.5, 375.5)
        )

        path.addCurve(
            to: point(405.7, 371.2),
            control1: point(417.8, 375.5),
            control2: point(411.4, 373.9)
        )

        path.addCurve(
            to: point(360.7, 401.0),
            control1: point(398.2, 388.7),
            control2: point(380.9, 401.0)
        )

        path.addCurve(
            to: point(314.8, 369.0),
            control1: point(339.6, 401.0),
            control2: point(321.7, 387.7)
        )

        path.addCurve(
            to: point(305.5, 370.0),
            control1: point(311.8, 369.6),
            control2: point(308.7, 370.0)
        )

        path.addCurve(
            to: point(260.1, 324.1),
            control1: point(280.4, 370.0),
            control2: point(260.1, 349.4)
        )

        path.addCurve(
            to: point(282.8, 284.3),
            control1: point(260.1, 307.1),
            control2: point(269.2, 292.3)
        )

        path.addCurve(
            to: point(278.5, 263.3),
            control1: point(280.0, 277.9),
            control2: point(278.5, 270.8)
        )

        path.addCurve(
            to: point(331.4, 210.5),
            control1: point(278.5, 234.1),
            control2: point(302.2, 210.5)
        )

        path.addCurve(
            to: point(373.3, 231.2),
            control1: point(348.4, 210.5),
            control2: point(363.6, 218.6)
        )

        path.closeSubpath()

        return path
    }

    /// Returns CGPath for use in Core Graphics drawing
    func cgPath(in rect: CGRect) -> CGPath {
        return path(in: rect).cgPath
    }
}
