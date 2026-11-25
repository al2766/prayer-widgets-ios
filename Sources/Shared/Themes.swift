import Foundation

/// Colours as plain numbers so the pure logic package stays free of UI code. Each target turns them into Colors.
public struct WidgetTheme: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let bg: UInt32
    public let text: UInt32
    public let secondary: UInt32
    public let accent: UInt32
    public let highlightBg: UInt32
    public let highlightText: UInt32

    public static let all: [WidgetTheme] = [
        WidgetTheme(id: "midnight", name: "Midnight and gold", bg: 0x0F1B2D, text: 0xF4EBDD, secondary: 0x9FB0C8, accent: 0xE8A24A, highlightBg: 0xE8A24A, highlightText: 0x0F1B2D),
        WidgetTheme(id: "ivory", name: "Ivory and charcoal", bg: 0xF7F2E8, text: 0x1B1B1B, secondary: 0x6B665C, accent: 0xC98A2B, highlightBg: 0x14223A, highlightText: 0xFFFFFF),
        WidgetTheme(id: "mono-dark", name: "Monochrome dark", bg: 0x141414, text: 0xF2F2F2, secondary: 0x8E8E8E, accent: 0xFFFFFF, highlightBg: 0xF2F2F2, highlightText: 0x141414),
        WidgetTheme(id: "mono-light", name: "Monochrome light", bg: 0xFFFFFF, text: 0x111111, secondary: 0x7A7A7A, accent: 0x111111, highlightBg: 0x111111, highlightText: 0xFFFFFF),
        WidgetTheme(id: "slate", name: "Muted slate", bg: 0x2B3441, text: 0xEDF1F5, secondary: 0xA3AFBD, accent: 0x8FB8DE, highlightBg: 0x8FB8DE, highlightText: 0x1B222C),
        WidgetTheme(id: "sand", name: "Warm sand and bronze", bg: 0xE9DCC3, text: 0x2E2418, secondary: 0x7A6A52, accent: 0x9A6B2F, highlightBg: 0x9A6B2F, highlightText: 0xFFF8EC),
    ]

    public static func byId(_ id: String) -> WidgetTheme { all.first { $0.id == id } ?? all[0] }
}

public enum WidgetSize: String { case small, medium }

/// How the information is arranged. Only layouts that fit a size are offered for it.
public enum WidgetLayout: String, CaseIterable, Identifiable {
    case classic, nextFocus, horizontal, compact, split
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classic: return "Classic timetable"
        case .nextFocus: return "Next prayer focus"
        case .horizontal: return "Horizontal timetable"
        case .compact: return "Compact timetable"
        case .split: return "Split"
        }
    }
    public var blurb: String {
        switch self {
        case .classic: return "All five prayers, start and jama'ah times."
        case .nextFocus: return "The next prayer big, with a countdown."
        case .horizontal: return "Prayers side by side across the widget."
        case .compact: return "Small square with all five times."
        case .split: return "Next prayer on one side, timetable on the other."
        }
    }
    public func supports(_ size: WidgetSize) -> Bool {
        switch self {
        case .classic, .nextFocus: return true
        case .horizontal, .split: return size == .medium
        case .compact: return size == .small
        }
    }
    /// The size a preview should be drawn at.
    public var previewSize: WidgetSize { supports(.medium) ? .medium : .small }

    /// The layout actually drawn for a size: the chosen one if it fits, else the closest that does.
    public func resolved(for size: WidgetSize) -> WidgetLayout {
        if supports(size) { return self }
        return size == .small ? .compact : .classic
    }
    public static func byId(_ id: String) -> WidgetLayout { WidgetLayout(rawValue: id) ?? .classic }
}
