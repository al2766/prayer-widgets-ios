import WidgetKit
import SwiftUI
import Shared

// Every widget shows what the app is set to: the default masjid's own timetable, or locally calculated times. There is no picker: change it in the app.

/// Which half of the day a lock screen widget shows.
enum LockPart {
    case left, right
    var prayers: [Prayer] { self == .left ? [.fajr, .sunrise, .dhuhr] : [.asr, .maghrib, .isha] }
}

struct PrayerEntry: TimelineEntry {
    let date: Date
    let mosqueName: String?     // nil = no default masjid chosen yet
    let day: PrayerResponse?    // nil = nothing real to show
    let note: String?           // plain-words problem or age note
    var smallTheme = WidgetTheme.all[0].id
    var mediumTheme = WidgetTheme.all[0].id
    var smallLayout = WidgetLayout.nextFocus.rawValue
    var mediumLayout = WidgetLayout.classic.rawValue
}

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        // The same times Home shows: the default masjid's last saved times, or times calculated for the saved city. Never invented.
        var day: PrayerResponse?
        if Store.usingMasjid, let slug = Store.defaultSlug { day = Cache().times(slug: slug) }
        else if let place = Store.place { day = LocalTimes.day(place: place, now: Date(), hanafiAsr: Store.hanafiAsr) }
        return PrayerEntry(date: Date(), mosqueName: day?.mosque.name, day: day, note: day == nil ? "Loading…" : nil,
                           smallTheme: Store.themeId(.small), mediumTheme: Store.themeId(.medium),
                           smallLayout: Store.layoutId(.small), mediumLayout: Store.layoutId(.medium))
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        Task {
            let first = await load(at: Date()).first
            // In the gallery, show sample times rather than a setup message.
            completion(context.isPreview && first?.day == nil ? placeholder(in: context) : (first ?? placeholder(in: context)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        Task {
            let entries = await load(at: Date())
            // Ask again in 3 hours, or sooner when no real times are available yet.
            var refresh = Date().addingTimeInterval(entries.first?.day == nil ? 30 * 60 : 3 * 3600)
            // Local times are worked out on the phone, so ask again just after midnight (UK) for the new day.
            if !Store.usingMasjid, let zone = TimeZone(identifier: LocalTimes.zoneId) {
                var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
                if let midnight = cal.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime), midnight < refresh { refresh = midnight }
            }
            completion(Timeline(entries: entries, policy: .after(refresh)))
        }
    }

    /// One entry now plus one at each later prayer today, so "next prayer" changes by itself without new network calls.
    private func load(at now: Date) async -> [PrayerEntry] {
        func entry(_ date: Date, _ name: String?, _ day: PrayerResponse?, _ note: String?) -> PrayerEntry {
            PrayerEntry(date: date, mosqueName: name, day: day, note: note,
                        smallTheme: Store.themeId(.small), mediumTheme: Store.themeId(.medium),
                        smallLayout: Store.layoutId(.small), mediumLayout: Store.layoutId(.medium))
        }
        if !Store.usingMasjid {
            guard let place = Store.place, let day = LocalTimes.day(place: place, now: now, hanafiAsr: Store.hanafiAsr) else {
                return [entry(now, nil, nil, "No city saved. Open the app to set up your prayer times")]
            }
            await Planner.reschedule(for: day)
            let tail = TimeLogic.schedule(day).map(\.at).filter { $0 > now }
            return ([now] + tail).map { entry($0, day.mosque.name, day, nil) }
        }
        guard let slug = Store.defaultSlug else {
            return [entry(now, nil, nil, "No masjid saved. Open the app to set up your prayer times")]
        }
        let cache = Cache()
        var day: PrayerResponse?
        var note: String?
        do {
            let (d, raw) = try await API.prayerTimes(slug: slug)
            day = d
            cache.saveTimes(raw, slug: slug)
        } catch {
            day = cache.times(slug: slug)          // last real answer, never invented
            note = day == nil ? "Times not available yet" : nil
        }
        guard let day else { return [entry(now, nil, nil, note)] }
        await Planner.reschedule(for: day)          // best effort: keeps today's alerts current
        let stale = TimeLogic.staleNote(day.freshness)
        let isToday = TimeLogic.isToday(day, now: now)
        let tail = isToday ? TimeLogic.schedule(day).map(\.at).filter { $0 > now } : []
        // Old times get a tiny tag: "Yesterday" for yesterday's day (the server adds the new day just after midnight), a date for anything older.
        let yesterday = TimeLogic.dateString(now.addingTimeInterval(-86_400), zoneId: day.mosque.timezone)
        let dateNote: String? = isToday ? stale : (day.date == yesterday ? "Yesterday" : "Times are from \(day.date)")
        return ([now] + tail).map { entry($0, day.mosque.name, day, dateNote) }
    }
}

// MARK: - Home screen

struct PrayerHomeView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        let size: WidgetSize = family == .systemSmall ? .small : .medium
        let theme = WidgetTheme.byId(size == .small ? entry.smallTheme : entry.mediumTheme)
        let layout = WidgetLayout.byId(size == .small ? entry.smallLayout : entry.mediumLayout).resolved(for: size)
        WidgetContent(day: entry.day, mosqueName: entry.mosqueName, note: entry.note, theme: theme, layout: layout, size: size, now: entry.date)
            .containerBackground(Color(hex: theme.bg), for: .widget)
    }
}

struct PrayerHomeWidget: Widget {
    let kind = "PrayerHome"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerHomeView(entry: entry)
        }
        .configurationDisplayName("Prayer times")
        .description("Today's prayer times for your masjid or your location. Change it in the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Lock screen

/// Names on top, start times in the middle row, jama'ah times underneath. The left one carries the little legend icons.
struct LockWidgetView: View {
    let entry: PrayerEntry
    let part: LockPart

    var body: some View {
        Group {
            if let day = entry.day { grid(day) }
            else { Text(entry.note ?? "Loading…").font(.caption2).multilineTextAlignment(.center) }
        }
        .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder private func grid(_ day: PrayerResponse) -> some View {
        let prayers = part.prayers
        let rows = Dictionary(uniqueKeysWithValues: TimeLogic.rows(day).map { ($0.prayer, $0) })
        let jam = rows.values.contains { $0.jamaah != nil }     // locally calculated times have no jama'ah row
        Grid(alignment: .center, horizontalSpacing: part == .left ? 5 : 9, verticalSpacing: 1) {
            GridRow {
                if part == .left { Color.clear.frame(width: 12, height: 1) }
                ForEach(prayers, id: \.self) { Text($0.short).fontWeight(.semibold) }
            }
            GridRow {
                if part == .left { Image(systemName: "clock").font(.system(size: 9)).frame(width: 12) }
                ForEach(prayers, id: \.self) { Text(rows[$0]?.begins ?? "–") }
            }
            if jam {
                GridRow {
                    if part == .left { DomeIcon().frame(width: 12) }
                    ForEach(prayers, id: \.self) { p in
                        Text(p == .sunrise ? "–" : (rows[p]?.jamaah ?? "–"))
                    }
                }
            }
        }
        .font(.system(size: 11)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
    }
}

struct PrayerLockLeftWidget: Widget {
    let kind = "PrayerLockLeft"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in LockWidgetView(entry: entry, part: .left) }
            .configurationDisplayName("Prayer times · Left")
            .description("Fajr, Sunrise and Dhuhr. Add the Right one next to it.")
            .supportedFamilies([.accessoryRectangular])
    }
}

struct PrayerLockRightWidget: Widget {
    let kind = "PrayerLockRight"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in LockWidgetView(entry: entry, part: .right) }
            .configurationDisplayName("Prayer times · Right")
            .description("Asr, Maghrib and Isha. Add the Left one next to it.")
            .supportedFamilies([.accessoryRectangular])
    }
}

@main
struct PrayerWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerHomeWidget()
        PrayerLockLeftWidget()
        PrayerLockRightWidget()
    }
}
