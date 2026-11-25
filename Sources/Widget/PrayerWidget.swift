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
    static var description = IntentDescription("Pick the mosque whose prayer times this widget shows.")
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
}

struct Provider<Intent: WidgetConfigurationIntent & MosqueChoosing>: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: .now, mosqueName: "Your mosque", day: nil, note: nil)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> PrayerEntry {
        await load(configuration, at: .now).first ?? placeholder(in: context)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<PrayerEntry> {
        let entries = await load(configuration, at: .now)
        // Ask again in 3 hours, or sooner when no real times are available yet.
        let refresh = Date.now.addingTimeInterval(entries.first?.day == nil ? 30 * 60 : 3 * 3600)
        return Timeline(entries: entries, policy: .after(refresh))
    }

    /// One entry now plus one at each later prayer today, so "next prayer" changes by itself without new network calls.
    private func load(_ config: Intent, at now: Date) async -> [PrayerEntry] {
        let part = config.part
        guard let m = config.mosque else { return [PrayerEntry(date: now, mosqueName: nil, day: nil, note: "Edit the widget to choose a mosque", part: part)] }
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
        guard let day else { return [PrayerEntry(date: now, mosqueName: m.name, day: nil, note: note, part: part)] }
        let stale = TimeLogic.staleNote(day.freshness)
        let isToday = day.date == TimeLogic.dateString(now, zoneId: day.mosque.timezone)
        let tail = isToday ? TimeLogic.schedule(day).map(\.at).filter { $0 > now } : []
        // Yesterday's times are shown without a label (the server adds the new day at 03:30 UTC); older than that gets a plain note.
        let yesterday = TimeLogic.dateString(now.addingTimeInterval(-86_400), zoneId: day.mosque.timezone)
        let dateNote: String? = (isToday || day.date == yesterday) ? stale : "Times are from \(day.date)"
        return ([now] + tail).map { PrayerEntry(date: $0, mosqueName: m.name, day: day, note: dateNote, part: part) }
    }
}

// MARK: - Views

private extension Prayer {
    /// Short names so every column fits.
    var short: String {
        switch self {
        case .maghrib: return "Magh"
        case .sunrise: return "Rise"
        default: return title
        }
    }
}

struct PrayerWidgetView: View {
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

    /// Name on the left, start time and jama'ah time side by side on the far right.
    @ViewBuilder private func content(_ day: PrayerResponse) -> some View {
        let next = TimeLogic.next(day, after: entry.date)
        VStack(alignment: .leading, spacing: 4) {
            Text(day.mosque.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            ForEach(TimeLogic.rows(day).filter { $0.prayer != .sunrise }, id: \.prayer) { row in
                let isNext = row.prayer == next?.row.prayer
                HStack(spacing: 8) {
                    Text(row.prayer.short)
                    Spacer(minLength: 4)
                    Text(row.begins ?? "–").frame(width: 46, alignment: .trailing)
                    Text(row.jamaah ?? "–").frame(width: 46, alignment: .trailing)
                }
                .font(.footnote).monospacedDigit().fontWeight(isNext ? .bold : .regular)
            }
            if let note = entry.note { Text(note).font(.caption2).foregroundStyle(.orange).lineLimit(1) }
        }
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
