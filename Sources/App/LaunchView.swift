import SwiftUI

private let tealBg = Color(hex: 0x0A3A45)
private let cream = Color(hex: 0xFBE9CF)
private let gold = Color(hex: 0xE8A24A)

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
                tealBg.ignoresSafeArea()
                // Warm glow rising behind the hills on the right.
                RadialGradient(colors: [gold.opacity(0.55), gold.opacity(0)], center: .bottomTrailing, startRadius: 10, endRadius: geo.size.width * 0.9)
                    .ignoresSafeArea().opacity(hills)
                HillsShape()
                    .fill(LinearGradient(colors: [Color(hex: 0x14596A), Color(hex: 0x082E38)], startPoint: .top, endPoint: .bottom))
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
