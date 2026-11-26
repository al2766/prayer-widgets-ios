import SwiftUI

/// The arch outline from the logo: an onion arch with a pointed top, open at the bottom.
struct ArchShape: Shape {
    func path(in r: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x / 100, y: r.minY + r.height * y / 120) }
        var p = Path()
        p.move(to: pt(0, 112))
        p.addLine(to: pt(0, 58))
        p.addCurve(to: pt(50, 0), control1: pt(0, 34), control2: pt(34, 18))
        p.addCurve(to: pt(100, 58), control1: pt(66, 18), control2: pt(100, 34))
        p.addLine(to: pt(100, 112))
        return p
    }
}

/// The dome with its spire, sitting inside the arch.
struct DomeShape: Shape {
    func path(in r: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x / 100, y: r.minY + r.height * y / 60) }
        var p = Path()
        p.move(to: pt(0, 60))
        p.addCurve(to: pt(46, 14), control1: pt(0, 34), control2: pt(22, 22))
        p.addLine(to: pt(50, 0))
        p.addLine(to: pt(54, 14))
        p.addCurve(to: pt(100, 60), control1: pt(78, 22), control2: pt(100, 34))
        p.closeSubpath()
        return p
    }
}

/// Rolling dark hills along the bottom with a lighter far ridge.
struct HillsShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.28))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.58),
                   control1: CGPoint(x: r.width * 0.45, y: r.maxY - r.height * 0.10),
                   control2: CGPoint(x: r.width * 0.72, y: r.maxY - r.height * 0.52))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A curved ridge line only (the glowing edge of a hill).
struct RidgeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.15),
                   control1: CGPoint(x: r.width * 0.35, y: r.maxY - r.height * 0.05),
                   control2: CGPoint(x: r.width * 0.7, y: r.minY + r.height * 0.25))
        return p
    }
}

/// Small outlined dome, the "jama'ah" symbol on the lock screen widget.
struct DomeIcon: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            DomeShape().stroke(style: StrokeStyle(lineWidth: 1.3, lineJoin: .round)).frame(width: 11, height: 7)
            Rectangle().frame(width: 12, height: 1.3)
        }
        .frame(width: 12, height: 9)
    }
}

/// The widget picture's decoration: a dome rising from a glowing hill, as in the mockups. Drawn in the theme's own colours.
struct DomeArt: View {
    let ink: Color
    let glow: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottomTrailing) {
                HillsShape().fill(ink.opacity(0.10)).frame(width: g.size.width, height: g.size.height * 0.45)
                RidgeShape().stroke(glow.opacity(0.9), lineWidth: 1.4).frame(width: g.size.width, height: g.size.height * 0.45)
                DomeShape().fill(ink.opacity(0.95)).frame(width: g.size.width * 0.52, height: g.size.width * 0.31)
                    .offset(x: -g.size.width * 0.06, y: -g.size.height * 0.07)
            }
            .frame(width: g.size.width, height: g.size.height, alignment: .bottomTrailing)
        }
    }
}

/// Tall arch outline with a dome inside, drawn at the right edge of the medium widget.
struct ArchArt: View {
    let ink: Color
    let glow: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                ArchShape().stroke(glow.opacity(0.55), lineWidth: 1.2).frame(width: g.size.width * 0.8, height: g.size.height * 0.92)
                DomeArt(ink: ink, glow: glow).frame(width: g.size.width, height: g.size.height * 0.55)
            }
            .frame(width: g.size.width, height: g.size.height, alignment: .bottom)
        }
    }
}
