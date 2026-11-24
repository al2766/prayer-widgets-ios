import WidgetKit
import SwiftUI
import AppIntents
import Shared

// MARK: - Mosque picker (shown when the user edits the widget)

struct MosqueEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Mosque"
    static var defaultQuery = MosqueQuery()
    var id: String            // the mosque's slug
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct MosqueQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MosqueEntity] {
        try await all().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [MosqueEntity] { try await all() }

    /// Network first, cached list when offline, so the picker is never empty after one good load.
    private func all() async -> [MosqueEntity] {
        let cache = Cache()
        if let list = try? await API.mosques() { cache.saveMosques(list); return list.map { MosqueEntity(id: $0.slug, name: $0.name) } }
        return cache.mosques().map { MosqueEntity(id: $0.slug, name: $0.name) }
    }
}

struct SelectMosqueIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose mosque"
    static var description = IntentDescription("Pick the mosque whose prayer times this widget shows.")
    @Parameter(title: "Mosque") var mosque: MosqueEntity?
}

// MARK: - Timeline

struct PrayerEntry: TimelineEntry {
    let date: Date
    let mosqueName: String?     // nil = no mosque chosen yet
    let day: PrayerResponse?    // nil = nothing real to show
    let note: String?           // plain-words problem or age note
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: .now, mosqueName: "Your mosque", day: nil, note: nil)
    }

    func snapshot(for configuration: SelectMosqueIntent, in context: Context) async -> PrayerEntry {
        await load(configuration, at: .now).first ?? placeholder(in: context)
    }

    func timeline(for configuration: SelectMosqueIntent, in context: Context) async -> Timeline<PrayerEntry> {
        let entries = await load(configuration, at: .now)
        // Ask again in 3 hours, or sooner when no real times are available yet.
        let refresh = Date.now.addingTimeInterval(entries.first?.day == nil ? 30 * 60 : 3 * 3600)
        return Timeline(entries: entries, policy: .after(refresh))
    }

    /// One entry now plus one at each later prayer today, so "next prayer" changes by itself without new network calls.
    private func load(_ config: SelectMosqueIntent, at now: Date) async -> [PrayerEntry] {
        guard let m = config.mosque else { return [PrayerEntry(date: now, mosqueName: nil, day: nil, note: "Edit the widget to choose a mosque")] }
        let cache = Cache()
        var day: PrayerResponse?
        var note: String?
        do {
            let (d, raw) = try await API.prayerTimes(slug: m.id)
            day = d
            cache.saveTimes(raw, slug: m.id)
        } catch {
            day = cache.times(slug: m.id)          // last real answer, never invented
            note = day == nil ? "Times not available yet" : nil
        }
        guard let day else { return [PrayerEntry(date: now, mosqueName: m.name, day: nil, note: note)] }
        let stale = TimeLogic.staleNote(day.freshness)
        let isToday = day.date == TimeLogic.dateString(now, zoneId: day.mosque.timezone)
        let tail = isToday ? TimeLogic.schedule(day).map(\.at).filter { $0 > now } : []
        return ([now] + tail).map { PrayerEntry(date: $0, mosqueName: m.name, day: day, note: isToday ? stale : "Showing \(day.date)") }
    }
}

// MARK: - Views

struct PrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        Group {
            if let day = entry.day { content(day) }
            else { VStack(spacing: 4) {
                Text(entry.mosqueName ?? "Prayer Widgets").font(.headline)
                Text(entry.note ?? "Choose a mosque").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder private func content(_ day: PrayerResponse) -> some View {
        let next = TimeLogic.next(day, after: entry.date)
        VStack(alignment: .leading, spacing: 4) {
            Text(day.mosque.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if let n = next, family == .systemSmall {
                Text(n.row.prayer.title).font(.title3.bold())
                Text(n.row.main ?? "").font(.largeTitle.bold())
            } else {
                ForEach(TimeLogic.rows(day).filter { $0.prayer != .sunrise }, id: \.prayer) { row in
                    HStack {
                        Text(row.prayer.title).fontWeight(row.prayer == next?.row.prayer ? .bold : .regular)
                        Spacer()
                        Text(row.main ?? "").monospacedDigit().fontWeight(row.prayer == next?.row.prayer ? .bold : .regular)
                    }.font(.footnote)
                }
            }
            if next == nil && family == .systemSmall { Text("Done for today").font(.headline) }
            if let note = entry.note { Text(note).font(.caption2).foregroundStyle(.orange).lineLimit(1) }
        }
    }
}

struct PrayerWidget: Widget {
    let kind = "PrayerWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectMosqueIntent.self, provider: Provider()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Prayer times")
        .description("Today's prayer times for your mosque.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PrayerWidgetBundle: WidgetBundle {
    var body: some Widget { PrayerWidget() }
}
