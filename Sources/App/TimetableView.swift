import SwiftUI
import Shared

/// Today's timetable: prayer, start time, jama'ah time. The next prayer sits in a teal bar.
struct TimetableView: View {
    let day: PrayerResponse
    let now: Date

    var body: some View {
        let next = TimeLogic.next(day, after: now)
        let rows = TimeLogic.rows(day)
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Start").frame(width: 78, alignment: .trailing)
                Text("Jama'ah").frame(width: 78, alignment: .trailing)
            }
            .font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.muted)
            .padding(.horizontal, 18).padding(.bottom, 10)

            ForEach(Array(rows.enumerated()), id: \.element.prayer) { i, row in
                let on = row.prayer == next?.row.prayer && row.prayer != .sunrise
                let isSunrise = row.prayer == .sunrise
                HStack(spacing: 10) {
                    if isSunrise { Image(systemName: "sunrise").font(.system(size: 22)).foregroundStyle(Palette.gold).frame(width: 40) }
                    Text(row.prayer.title).fontWeight(isSunrise ? .regular : .bold)
                    Spacer(minLength: 4)
                    Text(row.begins ?? "–").frame(width: 78, alignment: .trailing)
                    Text(isSunrise ? "" : (row.jamaah ?? "–")).frame(width: 78, alignment: .trailing)
                }
                .font(.system(size: isSunrise ? 19 : 21)).monospacedDigit()
                .foregroundStyle(isSunrise ? Palette.muted : Palette.text)
                .padding(.horizontal, 18).padding(.vertical, isSunrise ? 12 : 15)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(on ? Palette.nextRow : Color.clear))
                .animation(.easeInOut(duration: 0.3), value: on)
                if i < rows.count - 1, !on, rows[i + 1].prayer != next?.row.prayer { Divider().overlay(Palette.line).padding(.horizontal, 10) }
            }

            ForEach(Array(day.jumuah.enumerated()), id: \.offset) { i, t in
                Divider().overlay(Palette.line).padding(.horizontal, 10)
                HStack(spacing: 12) {
                    DomeGlyph(size: 26)
                    Text(day.jumuah.count > 1 ? "Jumu'ah \(i + 1)" : "Jumu'ah").fontWeight(.bold)
                    Spacer()
                    Text(t).monospacedDigit().frame(width: 78, alignment: .trailing)
                }
                .font(.system(size: 21)).foregroundStyle(Palette.teal)
                .padding(.horizontal, 18).padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.nextRow))
            }
        }
    }
}

/// "Updated today at 03:31" and any plain-words warning about old data.
struct FreshnessFooter: View {
    let day: PrayerResponse
    let note: String?
    let now: Date

    /// "Today, 03:31" becomes "today at 03:31".
    static func phrase(_ t: String) -> String {
        let p = t.replacingOccurrences(of: ", ", with: " at ")
        return (p.hasPrefix("Today") || p.hasPrefix("Yesterday")) ? p.prefix(1).lowercased() + p.dropFirst() : p
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let t = TimeLogic.updatedText(day.freshness, zoneId: day.mosque.timezone, now: now) {
                Label("Updated \(Self.phrase(t))", systemImage: "arrow.triangle.2.circlepath").font(.system(size: 14)).foregroundStyle(Palette.muted)
            }
            if let stale = TimeLogic.staleNote(day.freshness) { Text(stale).font(.system(size: 13)).foregroundStyle(.orange) }
            if let note { Text(note).font(.system(size: 13)).foregroundStyle(.orange) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }
}

/// Shown when the saved day is not today's, so old times are never passed off as today's.
struct OldTimesBanner: View {
    let day: PrayerResponse
    var body: some View {
        Label("These times are from \(day.date). Today's are not published yet.", systemImage: "exclamationmark.triangle")
            .font(.system(size: 14)).foregroundStyle(Color(hex: 0x8A4B00))
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.gold.opacity(0.22)))
    }
}
