import SwiftUI

nonisolated struct Corner: OptionSet {
    let rawValue: Int

    static let topLeft = Corner(rawValue: 1 << 0)
    static let topRight = Corner(rawValue: 1 << 1)
    static let bottomLeft = Corner(rawValue: 1 << 2)
    static let bottomRight = Corner(rawValue: 1 << 3)
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: Corner) -> some View {
        clipShape(RoundedCorners(radius: radius, corners: corners))
    }
}

nonisolated struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: Corner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topLeftRadius = corners.contains(.topLeft) ? radius : 0
        let topRightRadius = corners.contains(.topRight) ? radius : 0
        let bottomLeftRadius = corners.contains(.bottomLeft) ? radius : 0
        let bottomRightRadius = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + topLeftRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRightRadius, y: rect.minY))

        if topRightRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - topRightRadius, y: rect.minY + topRightRadius),
                radius: topRightRadius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRightRadius))

        if bottomRightRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - bottomRightRadius, y: rect.maxY - bottomRightRadius),
                radius: bottomRightRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        }

        path.addLine(to: CGPoint(x: rect.minX + bottomLeftRadius, y: rect.maxY))

        if bottomLeftRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + bottomLeftRadius, y: rect.maxY - bottomLeftRadius),
                radius: bottomLeftRadius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeftRadius))

        if topLeftRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + topLeftRadius, y: rect.minY + topLeftRadius),
                radius: topLeftRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }

        return path
    }
}
