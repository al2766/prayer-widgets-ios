import SwiftUI
import Shared

/// Today's timetable: prayer, start time, jama'ah time. The next prayer is highlighted in navy.
struct TimetableView: View {
    let day: PrayerResponse
    let now: Date

    var body: some View {
        let next = TimeLogic.next(day, after: now)
        let rows = TimeLogic.rows(day)
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Start").frame(width: 62, alignment: .trailing)
                Text("Jama'ah").frame(width: 62, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
            .padding(.horizontal, 14).padding(.bottom, 6)

            ForEach(Array(rows.enumerated()), id: \.element.prayer) { i, row in
                let on = row.prayer == next?.row.prayer && row.prayer != .sunrise
                let isSunrise = row.prayer == .sunrise
                HStack(spacing: 12) {
                    Image(systemName: row.prayer.icon).frame(width: 24).foregroundStyle(on ? Palette.amber : Palette.muted)
                    Text(row.prayer.title).fontWeight(on ? .bold : .semibold)
                    Spacer(minLength: 4)
                    Text(row.begins ?? "–").frame(width: 62, alignment: .trailing)
                    Text(isSunrise ? "" : (row.jamaah ?? "–")).frame(width: 62, alignment: .trailing)
                }
                .font(.system(size: isSunrise ? 15 : 17, weight: .regular)).monospacedDigit()
                .foregroundStyle(on ? Color.white : (isSunrise ? Palette.muted : Palette.text))
                .padding(.horizontal, 14).padding(.vertical, isSunrise ? 8 : 13)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Palette.navy : Color.clear))
                .animation(.easeInOut(duration: 0.3), value: on)
                if i < rows.count - 1, !on, rows[i + 1].prayer != next?.row.prayer { Divider().overlay(Palette.line).padding(.horizontal, 14) }
            }

            ForEach(Array(day.jumuah.enumerated()), id: \.offset) { i, t in
                Divider().overlay(Palette.line).padding(.horizontal, 14)
                HStack(spacing: 12) {
                    Image(systemName: "building.columns").frame(width: 24).foregroundStyle(Palette.muted)
                    Text(day.jumuah.count > 1 ? "Jumu'ah \(i + 1)" : "Jumu'ah").fontWeight(.semibold)
                    Spacer()
                    Text(t).monospacedDigit()
                }
                .font(.system(size: 17)).padding(.horizontal, 14).padding(.vertical, 13)
            }
        }
    }
}

/// "Last updated: Today, 14:58" and any plain-words warning about old data.
struct FreshnessFooter: View {
    let day: PrayerResponse
    let note: String?
    let now: Date

    var body: some View {
        VStack(spacing: 4) {
            if let t = TimeLogic.updatedText(day.freshness, zoneId: day.mosque.timezone, now: now) {
                Label("Last updated: \(t)", systemImage: "arrow.triangle.2.circlepath").font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
            if let stale = TimeLogic.staleNote(day.freshness) { Text(stale).font(.system(size: 13)).foregroundStyle(.orange) }
            if let note { Text(note).font(.system(size: 13)).foregroundStyle(.orange) }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Shown when the saved day is not today's, so old times are never passed off as today's.
struct OldTimesBanner: View {
    let day: PrayerResponse
    var body: some View {
        Label("These times are from \(day.date). Today's are not published yet.", systemImage: "exclamationmark.triangle")
            .font(.system(size: 14)).foregroundStyle(Color(hex: 0x8A4B00))
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.amberSoft.opacity(0.6)))
    }
}
