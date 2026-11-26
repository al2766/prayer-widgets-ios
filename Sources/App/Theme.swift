import SwiftUI
import UIKit
import Shared

/// Design tokens: warm ivory, deep teal, a little gold and coral. One place so every screen matches.
enum Palette {
    static let bg = Color(hex: 0xFBF7F0)
    static let surface = Color(hex: 0xF1ECE3)
    static let teal = Color(hex: 0x0B4F5E)          // main buttons, selected rows
    static let tealDeep = Color(hex: 0x083A47)
    static let tealMid = Color(hex: 0x126A7A)
    static let tealSoft = Color(hex: 0xDDEBEB)      // light fills (selected tab, chips)
    static let turquoise = Color(hex: 0x58D3DC)     // countdown text on teal
    static let mint = Color(hex: 0x3CCBA5)          // compass aligned
    static let gold = Color(hex: 0xE8A24A)
    static let goldDeep = Color(hex: 0xB9822F)
    static let coral = Color(hex: 0xD9694A)
    static let coralSoft = Color(hex: 0xF8E3DB)
    static let text = Color(hex: 0x14262B)
    static let muted = Color(hex: 0x6E716F)
    static let line = Color(hex: 0xE5DED2)
    static let nextRow = Color(hex: 0xE3EFE9)       // pale green: next prayer row, Jumu'ah row
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// Big teal button used for the main action on a screen.
struct TealButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.teal.opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet grey-green button (Cancel).
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Palette.teal)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Round icon button used in headers (bell, pin).
struct RoundIcon: View {
    let system: String
    var tint: Color = Palette.text
    var fill: Color = Palette.surface
    var size: CGFloat = 46
    var body: some View {
        Image(systemName: system).font(.system(size: size * 0.4, weight: .regular)).foregroundStyle(tint)
            .frame(width: size, height: size).background(Circle().fill(fill))
    }
}

extension Prayer {
    var icon: String {
        switch self {
        case .fajr: return "sunrise"
        case .sunrise: return "sun.horizon"
        case .dhuhr: return "sun.max"
        case .asr: return "cloud.sun"
        case .maghrib: return "sunset"
        case .isha: return "moon"
        }
    }
}

/// A masjid's own logo when the Studio has one, else the teal dome tile. Logos sit on white so transparent ones stay readable.
struct MasjidLogo: View {
    let mosque: Mosque
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let url = API.logoURL(mosque) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFit().padding(size * 0.1)
                    default: fallback
                    }
                }
                .background(Color.white)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            Palette.tealSoft
            DomeShape().stroke(Palette.teal, style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
                .frame(width: size * 0.42, height: size * 0.28).offset(y: -size * 0.04)
            Rectangle().fill(Palette.teal).frame(width: size * 0.48, height: 2.4).offset(y: size * 0.13)
        }
    }
}

/// Outlined (or filled) dome, used as the Masjids tab icon and for Jumu'ah.
struct DomeGlyph: View {
    var filled = false
    var size: CGFloat = 24
    var body: some View {
        ZStack(alignment: .bottom) {
            if filled { DomeShape().fill() .frame(width: size * 0.86, height: size * 0.56) .offset(y: -size * 0.06) }
            else { DomeShape().stroke(style: StrokeStyle(lineWidth: max(1.6, size * 0.085), lineJoin: .round)).frame(width: size * 0.86, height: size * 0.56).offset(y: -size * 0.06) }
            Capsule().frame(width: size, height: max(1.8, size * 0.09))
        }
        .frame(width: size, height: size * 0.8)
    }
}

/// Keeps the edge swipe-back working on screens that hide the system navigation bar.
extension UINavigationController: UIGestureRecognizerDelegate {
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { viewControllers.count > 1 }
}
