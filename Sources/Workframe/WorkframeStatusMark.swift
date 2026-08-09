import SwiftUI

/// The Workframe brace mark, traced from the supplied 72×54 SVG. The menu bar
/// renders it as a 24×18 point template glyph via `.primary`, allowing macOS
/// to choose the correct light or dark appearance.
struct WorkframeStatusMark: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 72, y: rect.minY + rect.height * y / 54)
        }

        var mark = Path()

        mark.move(to: point(64, 54))
        mark.addLine(to: point(54, 54))
        mark.addLine(to: point(54, 45))
        mark.addLine(to: point(63, 45))
        mark.addLine(to: point(63, 37))
        mark.addLine(to: point(54, 37))
        mark.addLine(to: point(54, 17))
        mark.addLine(to: point(63, 17))
        mark.addLine(to: point(63, 9))
        mark.addLine(to: point(54, 9))
        mark.addLine(to: point(54, 0))
        mark.addLine(to: point(64, 0))
        mark.addLine(to: point(64, 8))
        mark.addLine(to: point(72, 8))
        mark.addLine(to: point(72, 18))
        mark.addLine(to: point(64, 18))
        mark.addLine(to: point(64, 36))
        mark.addLine(to: point(72, 36))
        mark.addLine(to: point(72, 46))
        mark.addLine(to: point(64, 46))
        mark.closeSubpath()

        mark.addRect(CGRect(x: point(27, 45).x, y: point(27, 45).y, width: rect.width * 18 / 72, height: rect.height * 9 / 54))
        mark.addRect(CGRect(x: point(27, 0).x, y: point(27, 0).y, width: rect.width * 18 / 72, height: rect.height * 9 / 54))

        mark.move(to: point(8, 54))
        mark.addLine(to: point(18, 54))
        mark.addLine(to: point(18, 45))
        mark.addLine(to: point(9, 45))
        mark.addLine(to: point(9, 37))
        mark.addLine(to: point(18, 37))
        mark.addLine(to: point(18, 17))
        mark.addLine(to: point(9, 17))
        mark.addLine(to: point(9, 9))
        mark.addLine(to: point(18, 9))
        mark.addLine(to: point(18, 0))
        mark.addLine(to: point(8, 0))
        mark.addLine(to: point(8, 8))
        mark.addLine(to: point(0, 8))
        mark.addLine(to: point(0, 18))
        mark.addLine(to: point(8, 18))
        mark.addLine(to: point(8, 36))
        mark.addLine(to: point(0, 36))
        mark.addLine(to: point(0, 46))
        mark.addLine(to: point(8, 46))
        mark.closeSubpath()

        return mark
    }
}
