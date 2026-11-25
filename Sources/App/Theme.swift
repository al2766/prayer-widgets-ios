import SwiftUI
import UIKit
import Shared

/// Design tokens: warm ivory, midnight navy, amber. One place so every screen matches.
enum Palette {
    static let bg = Color(hex: 0xFBF7EF)
    static let surface = Color(hex: 0xF2ECE0)
    static let navy = Color(hex: 0x14223A)
    static let amber = Color(hex: 0xE8A24A)
    static let amberSoft = Color(hex: 0xF7D9A4)
    static let text = Color(hex: 0x1B1B1B)
    static let muted = Color(hex: 0x6B665C)
    static let line = Color(hex: 0xE3DBCB)
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// Big navy button used for the main action on a screen.
struct NavyButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.navy.opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
