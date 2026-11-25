import SwiftUI

private let navyBg = Color(hex: 0x0F1B2D)
private let cream = Color(hex: 0xFBE9CF)
private let gold = Color(hex: 0xE8A24A)

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

/// Plays once at launch while the app loads its data underneath, then calls `onFinish`.
/// About 2.3 seconds; with Reduce Motion on it just shows the finished logo briefly.
struct LaunchView: View {
    let ready: Bool
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arch: CGFloat = 0
    @State private var dome: CGFloat = 0
    @State private var hills: CGFloat = 0
    @State private var finishedPlaying = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                navyBg.ignoresSafeArea()
                // Warm glow rising behind the hills on the right.
                RadialGradient(colors: [gold.opacity(0.55), gold.opacity(0)], center: .bottomTrailing, startRadius: 10, endRadius: geo.size.width * 0.9)
                    .ignoresSafeArea().opacity(hills)
                HillsShape()
                    .fill(LinearGradient(colors: [Color(hex: 0x23324A), Color(hex: 0x111E33)], startPoint: .top, endPoint: .bottom))
                    .frame(height: geo.size.height * 0.34)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(x: (1 - hills) * 90).opacity(hills)
                    .ignoresSafeArea()

                ZStack {
                    ArchShape().trim(from: 0, to: arch)
                        .stroke(LinearGradient(colors: [cream, gold], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 13, lineCap: .butt, lineJoin: .miter))
                        .frame(width: 150, height: 180)
                        .shadow(color: gold.opacity(0.45 * arch), radius: 14)
                    DomeShape().fill(LinearGradient(colors: [cream, gold], startPoint: .top, endPoint: .bottom))
                        .frame(width: 80, height: 48)
                        .offset(y: 56 + (1 - dome) * 26).opacity(dome)
                }
                .offset(y: -geo.size.height * 0.06)
            }
        }
        .task { await play() }
        .accessibilityHidden(true)
    }

    private func play() async {
        let start = Date()
        if reduceMotion {
            arch = 1; dome = 1; hills = 1
            try? await Task.sleep(nanoseconds: 700_000_000)
        } else {
            withAnimation(.easeInOut(duration: 0.8)) { arch = 1 }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { dome = 1 }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.easeOut(duration: 0.9)) { hills = 1 }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        finishedPlaying = true
        // Wait for the data, but never hold the screen longer than 3.5 seconds in total.
        while !ready && Date().timeIntervalSince(start) < 3.5 {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        onFinish()
    }
}
