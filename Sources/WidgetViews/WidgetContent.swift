import SwiftUI
import Shared

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

extension Prayer {
    /// Short names so every column fits.
    var short: String {
        switch self {
        case .maghrib: return "Magh"
        case .sunrise: return "Rise"
        default: return title
        }
    }
}

/// The widget picture. The home-screen widget and the in-app preview both draw this, so they always match.
/// It draws no background: the widget gives it one with containerBackground, the app preview draws its own.
struct WidgetContent: View {
    let day: PrayerResponse?
    let mosqueName: String?
    let note: String?
    let theme: WidgetTheme
    let layout: WidgetLayout       // already resolved for `size`
    let size: WidgetSize
    let now: Date

    private var text: Color { Color(hex: theme.text) }
    private var secondary: Color { Color(hex: theme.secondary) }
    private var accent: Color { Color(hex: theme.accent) }
    private var small: Bool { size == .small }

    var body: some View {
        Group {
            if let day { drawn(day) } else { empty }
        }
        .foregroundStyle(text)
    }

    // MARK: Pieces

    private var empty: some View {
        VStack(spacing: 4) {
            Text(mosqueName ?? "Prayer Widgets").font(.headline).lineLimit(2).minimumScaleFactor(0.7)
            Text(note ?? "Loading…").font(.caption).foregroundStyle(secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func prayers(_ day: PrayerResponse) -> [Row] { TimeLogic.rows(day).filter { $0.prayer != .sunrise } }

    private func header(_ day: PrayerResponse, big: Bool = false) -> some View {
        Text(day.mosque.name)
            .font(.system(size: big ? 17 : (small ? 11 : 12), weight: big ? .bold : .semibold))
            .foregroundStyle(big ? text : secondary)
            .lineLimit(1).minimumScaleFactor(0.6)
    }

    private func noteView() -> some View {
        Group {
            if let note { Text(note).font(.system(size: 10)).foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.7) }
        }
    }

    private func pill(_ on: Bool) -> some View {
        Capsule().fill(on ? Color(hex: theme.highlightBg) : Color.clear)
    }
    private func ink(_ on: Bool) -> Color { on ? Color(hex: theme.highlightText) : text }

    // MARK: Layouts

    @ViewBuilder private func drawn(_ day: PrayerResponse) -> some View {
        let next = TimeLogic.next(day, after: now)
        switch layout {
        case .classic: classic(day, next: next)
        case .nextFocus: if let n = next { nextFocus(day, n) } else { classic(day, next: nil) }
        case .horizontal: horizontal(day, next: next)
        case .compact: compact(day, next: next)
        case .split: if let n = next { split(day, n) } else { classic(day, next: nil) }
        }
    }

    /// Name on the left, start time and jama'ah time side by side. The medium widget adds column headings and the dome picture.
    private func classic(_ day: PrayerResponse, next: (row: Row, at: Date)?) -> some View {
        let w: CGFloat = small ? 36 : 52
        let jam = TimeLogic.rows(day).contains { $0.jamaah != nil }     // locally calculated times have no jama'ah
        let table = VStack(alignment: .leading, spacing: small ? 3 : 4) {
            header(day, big: !small)
            if !small {
                HStack(spacing: 8) {
                    Text("Prayer")
                    Spacer(minLength: 2)
                    Text("Start").frame(width: w, alignment: .trailing)
                    if jam { Text("Jama'ah").frame(width: w + 6, alignment: .trailing) }
                }
                .font(.system(size: 10, weight: .medium)).foregroundStyle(secondary).padding(.horizontal, 6)
            }
            ForEach(prayers(day), id: \.prayer) { row in
                let on = row.prayer == next?.row.prayer
                HStack(spacing: small ? 4 : 8) {
                    Text(row.prayer.title)
                    Spacer(minLength: 2)
                    Text(row.begins ?? "–").frame(width: w, alignment: .trailing)
                    if jam { Text(row.jamaah ?? "–").frame(width: small ? w : w + 6, alignment: .trailing) }
                }
                .font(.system(size: small ? 11 : 13, weight: on ? .bold : .semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(ink(on))
                .padding(.horizontal, 6).padding(.vertical, 1.5)
                .background(pill(on))
            }
            noteView()
        }
        return HStack(alignment: .bottom, spacing: 4) {
            table.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if !small { ArchArt(ink: text, glow: accent).frame(width: 84).frame(maxHeight: .infinity) }
        }
    }

    private func nextFocus(_ day: PrayerResponse, _ n: (row: Row, at: Date)) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if small { DomeArt(ink: text, glow: accent).frame(width: 92, height: 66).offset(x: 14, y: 14) }
            if small { nextSmall(n) } else { nextMedium(day, n) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Small square, as in the mockup: prayer name, big time, countdown.
    private func nextSmall(_ n: (row: Row, at: Date)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(n.row.prayer.title).font(.system(size: 24, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(n.row.main ?? "").font(.system(size: 42, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            (Text("in ") + Text(n.at, style: .relative)).font(.system(size: 14, weight: .semibold)).foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            noteView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func nextMedium(_ day: PrayerResponse, _ n: (row: Row, at: Date)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            header(day)
            Spacer(minLength: 0)
            Text("Next prayer").font(.system(size: 10, weight: .medium)).foregroundStyle(secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(n.row.prayer.title).font(.system(size: 20, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(n.row.main ?? "").font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            }
            (Text("in ") + Text(n.at, style: .relative)).font(.system(size: 12)).foregroundStyle(accent).lineLimit(1)
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                ForEach(prayers(day), id: \.prayer) { row in
                    let on = row.prayer == n.row.prayer
                    VStack(spacing: 1) {
                        Text(row.prayer.short).font(.system(size: 10, weight: .medium))
                        Text(row.main ?? "–").font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 8).fill(on ? Color(hex: theme.highlightBg) : Color.clear))
                    .foregroundStyle(on ? Color(hex: theme.highlightText) : text)
                }
            }
            noteView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func horizontal(_ day: PrayerResponse, next: (row: Row, at: Date)?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(day)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(prayers(day), id: \.prayer) { row in
                    let on = row.prayer == next?.row.prayer
                    VStack(spacing: 4) {
                        Text(row.prayer.short).font(.system(size: 12, weight: .bold))
                        Text(row.begins ?? "–").font(.system(size: 13, weight: .semibold)).monospacedDigit()
                        if TimeLogic.rows(day).contains(where: { $0.jamaah != nil }) {
                            Text(row.jamaah ?? "–").font(.system(size: 13)).monospacedDigit().foregroundStyle(on ? Color(hex: theme.highlightText) : secondary)
                        }
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(on ? Color(hex: theme.highlightBg) : Color.clear))
                    .foregroundStyle(on ? Color(hex: theme.highlightText) : text)
                }
            }
            Spacer(minLength: 0)
            noteView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Small square: one time per prayer (jama'ah when published).
    private func compact(_ day: PrayerResponse, next: (row: Row, at: Date)?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            header(day)
            ForEach(prayers(day), id: \.prayer) { row in
                let on = row.prayer == next?.row.prayer
                HStack {
                    Text(row.prayer.short)
                    Spacer(minLength: 2)
                    Text(row.main ?? "–").monospacedDigit()
                }
                .font(.system(size: 13, weight: on ? .bold : .regular))
                .lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(ink(on))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(pill(on))
            }
            noteView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func split(_ day: PrayerResponse, _ n: (row: Row, at: Date)) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                header(day)
                Spacer(minLength: 0)
                Text("Next prayer").font(.system(size: 10, weight: .medium)).foregroundStyle(secondary)
                Text(n.row.prayer.title).font(.system(size: 18, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(n.row.main ?? "").font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                (Text("in ") + Text(n.at, style: .relative)).font(.system(size: 12)).foregroundStyle(accent).lineLimit(1)
                noteView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VStack(spacing: 3) {
                ForEach(prayers(day), id: \.prayer) { row in
                    let on = row.prayer == n.row.prayer
                    HStack {
                        Text(row.prayer.short)
                        Spacer(minLength: 2)
                        Text(row.main ?? "–").monospacedDigit()
                    }
                    .font(.system(size: 12, weight: on ? .bold : .regular))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .foregroundStyle(ink(on))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(pill(on))
                }
            }
            .frame(width: 128)
        }
    }
}

/// One finished widget picture on its themed background, used for the previews inside the app.
struct WidgetPreviewCard: View {
    let day: PrayerResponse?
    let theme: WidgetTheme
    let layout: WidgetLayout
    let size: WidgetSize
    let now: Date

    var body: some View {
        let l = layout.resolved(for: size)
        WidgetContent(day: day, mosqueName: nil, note: day == nil ? "Set up your prayer times to preview" : nil, theme: theme, layout: l, size: size, now: now)
            .padding(16)
            .frame(width: size == .small ? 158 : 338, height: 158)
            .background(Color(hex: theme.bg))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
