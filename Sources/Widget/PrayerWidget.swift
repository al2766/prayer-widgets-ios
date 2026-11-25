import WidgetKit
import SwiftUI
import AppIntents
import Shared

// MARK: - Mosque picker (shown when the user edits the widget)

struct MosqueEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Mosque"
    static var defaultQuery = MosqueQuery()
    static let followDefaultId = "default"
    var id: String            // the mosque's slug, or "default" to follow the app's default masjid
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    static let followDefault = MosqueEntity(id: followDefaultId, name: "My default masjid")
}

struct MosqueQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MosqueEntity] {
        let all = await mosques()
        return identifiers.compactMap { id in id == MosqueEntity.followDefaultId ? MosqueEntity.followDefault : all.first { $0.id == id } }
    }
    func suggestedEntities() async throws -> [MosqueEntity] { [MosqueEntity.followDefault] + (await mosques()) }
    func defaultResult() async -> MosqueEntity? { MosqueEntity.followDefault }

    /// Network first, cached list when offline, so the picker is never empty after one good load.
    private func mosques() async -> [MosqueEntity] {
        let cache = Cache()
        if let list = try? await API.mosques() { cache.saveMosques(list); return list.map { MosqueEntity(id: $0.slug, name: $0.name) } }
        return cache.mosques().map { MosqueEntity(id: $0.slug, name: $0.name) }
    }
}

/// Which half of the day a lock screen widget shows.
enum LockPart: String, AppEnum {
    case left, right
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Half"
    static var caseDisplayRepresentations: [LockPart: DisplayRepresentation] = [
        .left: "Left: Fajr, Sunrise, Dhuhr",
        .right: "Right: Asr, Maghrib, Isha",
    ]
}

/// What the timeline needs from any widget's settings.
protocol MosqueChoosing {
    var mosque: MosqueEntity? { get }
    var part: LockPart { get }
}

struct SelectMosqueIntent: WidgetConfigurationIntent, MosqueChoosing {
    static var title: LocalizedStringResource = "Choose mosque"
    static var description = IntentDescription("Pick a mosque, or follow your default masjid from the app.")
    @Parameter(title: "Mosque") var mosque: MosqueEntity?
    var part: LockPart { .left }
}

struct SelectLockIntent: WidgetConfigurationIntent, MosqueChoosing {
    static var title: LocalizedStringResource = "Choose mosque and half"
    static var description = IntentDescription("Pick the mosque and which half of the day this widget shows. Add two widgets, one left and one right.")
    @Parameter(title: "Mosque") var mosque: MosqueEntity?
    @Parameter(title: "Half", default: .left) var part: LockPart
}

// MARK: - Timeline

struct PrayerEntry: TimelineEntry {
    let date: Date
    let mosqueName: String?     // nil = no mosque chosen yet
    let day: PrayerResponse?    // nil = nothing real to show
    let note: String?           // plain-words problem or age note
    var part: LockPart = .left  // lock screen widgets only
    var themeId: String = WidgetTheme.all[0].id
    var layoutId: String = WidgetLayout.classic.rawValue
}

struct Provider<Intent: WidgetConfigurationIntent & MosqueChoosing>: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), mosqueName: "Your mosque", day: nil, note: nil)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> PrayerEntry {
        await load(configuration, at: Date()).first ?? placeholder(in: context)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<PrayerEntry> {
        let entries = await load(configuration, at: Date())
        // Ask again in 3 hours, or sooner when no real times are available yet.
        let refresh = Date().addingTimeInterval(entries.first?.day == nil ? 30 * 60 : 3 * 3600)
        return Timeline(entries: entries, policy: .after(refresh))
    }

    /// One entry now plus one at each later prayer today, so "next prayer" changes by itself without new network calls.
    private func load(_ config: Intent, at now: Date) async -> [PrayerEntry] {
        let part = config.part
        let themeId = Store.themeId, layoutId = Store.layoutId
        let chosen = config.mosque?.id
        let followsDefault = chosen == nil || chosen == MosqueEntity.followDefaultId
        guard let slug = followsDefault ? Store.defaultSlug : chosen else {
            return [PrayerEntry(date: now, mosqueName: nil, day: nil, note: "Open the app and choose a default masjid", part: part, themeId: themeId, layoutId: layoutId)]
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
        guard let day else { return [PrayerEntry(date: now, mosqueName: config.mosque?.name, day: nil, note: note, part: part, themeId: themeId, layoutId: layoutId)] }
        if slug == Store.defaultSlug { await Planner.reschedule(for: day) }   // best effort: keeps today's alerts current
        let stale = TimeLogic.staleNote(day.freshness)
        let isToday = TimeLogic.isToday(day, now: now)
        let tail = isToday ? TimeLogic.schedule(day).map(\.at).filter { $0 > now } : []
        // Old times get a tiny tag: "Yesterday" for yesterday's day (the server adds the new day just after midnight), a date for anything older.
        let yesterday = TimeLogic.dateString(now.addingTimeInterval(-86_400), zoneId: day.mosque.timezone)
        let dateNote: String? = isToday ? stale : (day.date == yesterday ? "Yesterday" : "Times are from \(day.date)")
        return ([now] + tail).map { PrayerEntry(date: $0, mosqueName: day.mosque.name, day: day, note: dateNote, part: part, themeId: themeId, layoutId: layoutId) }
    }
}

// MARK: - Views

struct PrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        let theme = WidgetTheme.byId(entry.themeId)
        let size: WidgetSize = family == .systemSmall ? .small : .medium
        WidgetContent(day: entry.day, mosqueName: entry.mosqueName, note: entry.note, theme: theme,
                      layout: WidgetLayout.byId(entry.layoutId).resolved(for: size), size: size, now: entry.date)
            .containerBackground(Color(hex: theme.bg), for: .widget)
    }
}

/// Lock screen: names on top, start times in the middle row, jama'ah times underneath.
struct LockWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        Group {
            if let day = entry.day { grid(day) }
            else { Text(entry.note ?? "Edit widget: choose a mosque").font(.caption2).multilineTextAlignment(.center) }
        }
        .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder private func grid(_ day: PrayerResponse) -> some View {
        let prayers: [Prayer] = entry.part == .left ? [.fajr, .sunrise, .dhuhr] : [.asr, .maghrib, .isha]
        let rows = Dictionary(uniqueKeysWithValues: TimeLogic.rows(day).map { ($0.prayer, $0) })
        Grid(alignment: .trailing, horizontalSpacing: 6, verticalSpacing: 1) {
            GridRow {
                Text("")
                ForEach(prayers, id: \.self) { Text($0.short) }
            }
            GridRow {
                Text("⏰")
                ForEach(prayers, id: \.self) { Text(rows[$0]?.begins ?? "–") }
            }
            GridRow {
                Text("🕌")
                ForEach(prayers, id: \.self) { p in Text(rows[p]?.jamaah ?? (p == .sunrise ? rows[p]?.begins : nil) ?? "–") }
            }
        }
        .font(.system(size: 11)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
    }
}

struct PrayerWidget: Widget {
    let kind = "PrayerWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectMosqueIntent.self, provider: Provider<SelectMosqueIntent>()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Prayer times")
        .description("Today's prayer times for your mosque.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PrayerLockWidget: Widget {
    let kind = "PrayerLockWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectLockIntent.self, provider: Provider<SelectLockIntent>()) { entry in
            LockWidgetView(entry: entry)
        }
        .configurationDisplayName("Prayer times (lock screen)")
        .description("Start and jama'ah times. Add two: one left half, one right half.")
        .supportedFamilies([.accessoryRectangular])
    }
}

@main
struct PrayerWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerWidget()
        PrayerLockWidget()
    }
}
