import SwiftUI
import WidgetKit
import Shared

/// The one source of truth for the whole app: mosques, the default masjid, loaded days and widget choices.
@MainActor
final class AppState: ObservableObject {
    @Published var mosques: [Mosque] = Cache().mosques()
    @Published var mosquesMessage: String?
    @Published var loadingMosques = false
    @Published var defaultSlug: String? = Store.defaultSlug
    @Published var usingMasjid = Store.usingMasjid          // false = locally calculated times
    @Published var place: Place? = Store.place              // the city or detected place used for local times and Qibla
    @Published var hanafiAsr = Store.hanafiAsr
    @Published var onboarded = Store.onboarded
    @Published var days: [String: PrayerResponse] = [:]
    @Published var dayNotes: [String: String] = [:]
    @Published var themeIds: [WidgetSize: String] = Dictionary(uniqueKeysWithValues: WidgetSize.allCases.map { ($0, Store.themeId($0)) })
    @Published var layoutIds: [WidgetSize: String] = Dictionary(uniqueKeysWithValues: WidgetSize.allCases.map { ($0, Store.layoutId($0)) })
    @Published var requests: [SavedRequest] = Store.requests
    @Published var selectedTab = 0
    @Published var toast: String?
    @Published var bootstrapped = false

    init() {
        if let slug = Store.defaultSlug, let cached = Cache().times(slug: slug) { days[slug] = cached }
    }

    var defaultMosque: Mosque? { mosques.first { $0.slug == defaultSlug } }
    var defaultDay: PrayerResponse? { defaultSlug.flatMap { days[$0] } }
    /// What Home and the widgets show right now: the default masjid's timetable, or today's calculated local times.
    func activeDay(at now: Date = Date()) -> PrayerResponse? {
        if usingMasjid { return defaultDay }
        guard let place else { return nil }
        return LocalTimes.day(place: place, now: now, hanafiAsr: hanafiAsr)
    }
    /// Plain words for the setup card and Settings.
    var prayerTimesSummary: String? {
        if usingMasjid { return defaultMosque?.name ?? "My masjid" }
        return place == nil ? nil : "Local prayer times"
    }
    func theme(_ size: WidgetSize) -> WidgetTheme { WidgetTheme.byId(themeIds[size] ?? WidgetTheme.all[0].id) }
    func layout(_ size: WidgetSize) -> WidgetLayout { WidgetLayout.byId(layoutIds[size] ?? WidgetLayout.classic.rawValue) }

    // MARK: Loading

    /// Runs at launch: mosque list and the default masjid's times together. Never throws; failures become plain messages.
    func bootstrap() async {
        async let a: Void = loadMosques()
        async let b: Void = refreshDefault()
        _ = await (a, b)
        bootstrapped = true
    }

    func loadMosques() async {
        loadingMosques = true
        defer { loadingMosques = false }
        do {
            let list = try await API.mosques()
            mosques = list
            Cache().saveMosques(list)
            mosquesMessage = nil
        } catch {
            mosquesMessage = mosques.isEmpty ? "Could not load the masjid list. Pull down to try again." : "Offline: showing the last list."
        }
    }

    func refreshDefault() async {
        guard usingMasjid, let slug = defaultSlug else {
            await Planner.reschedule(for: activeDay())
            return
        }
        await loadDay(slug)
        await Planner.reschedule(for: days[slug])
    }

    /// Fetches today's times. On failure keeps the last saved real answer and says so; never invents times.
    func loadDay(_ slug: String) async {
        let cache = Cache()
        do {
            let (d, raw) = try await API.prayerTimes(slug: slug)
            days[slug] = d
            dayNotes[slug] = nil
            cache.saveTimes(raw, slug: slug)
        } catch API.Failure.http(404) {
            days[slug] = days[slug] ?? cache.times(slug: slug)
            dayNotes[slug] = days[slug] == nil ? "Today's times are not published yet. Try again later." : nil
        } catch {
            days[slug] = days[slug] ?? cache.times(slug: slug)
            dayNotes[slug] = days[slug] == nil ? "Could not load the times. Check your connection." : "Offline: showing the last saved times."
        }
    }

    // MARK: Choices

    func setDefault(_ m: Mosque) async {
        Store.defaultSlug = m.slug
        Store.source = "masjid"
        defaultSlug = m.slug
        usingMasjid = true
        Haptics.success()
        showToast("\(m.name) is now your default")
        WidgetCenter.shared.reloadAllTimelines()
        await loadDay(m.slug)
        await Planner.reschedule(for: days[m.slug])
    }

    /// Switches Home and the widgets back to the default masjid's own timetable.
    func useMasjid() async {
        guard let slug = defaultSlug else { return }
        Store.source = "masjid"
        usingMasjid = true
        Haptics.success()
        WidgetCenter.shared.reloadAllTimelines()
        await loadDay(slug)
        await Planner.reschedule(for: days[slug])
    }

    /// Switches Home and the widgets to locally calculated times for a place. The default masjid, if any, is kept for later.
    func useLocalTimes(place p: Place? = nil) async {
        if let p { setPlace(p) }
        Store.source = "local"
        usingMasjid = false
        Haptics.success()
        WidgetCenter.shared.reloadAllTimelines()
        await Planner.reschedule(for: activeDay())
    }

    /// Saves the user's place. Local times, distances and the Qibla all use it.
    func setPlace(_ p: Place) {
        Store.place = p
        place = p
        WidgetCenter.shared.reloadAllTimelines()
        Task { await Planner.reschedule(for: activeDay()) }
    }

    func setHanafiAsr(_ on: Bool) {
        Store.hanafiAsr = on
        hanafiAsr = on
        Haptics.tap()
        WidgetCenter.shared.reloadAllTimelines()
        Task { await Planner.reschedule(for: activeDay()) }
    }

    func finishOnboarding() {
        Store.onboarded = true
        onboarded = true
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// How many of the three setup steps are done: prayer times, location, notifications.
    var setupDone: Int { [prayerTimesSummary != nil, place != nil, Store.notifyPrayers || Store.notifySunrise].filter { $0 }.count }

    func setTheme(_ t: WidgetTheme, for size: WidgetSize) {
        Store.setThemeId(t.id, for: size); themeIds[size] = t.id
        Haptics.success(); showToast("Theme saved. Widgets are updating")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setLayout(_ l: WidgetLayout, for size: WidgetSize) {
        Store.setLayoutId(l.rawValue, for: size); layoutIds[size] = l.rawValue
        Haptics.success(); showToast("Layout saved. Widgets are updating")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Requests

    /// Sends a request and remembers it on this phone so My Requests can show what happened to it.
    func sendRequest(url: String, name: String) async throws {
        let id = try await API.requestMosque(url: url, name: name)
        if let id {
            var list = requests.filter { $0.id != id }
            list.insert(SavedRequest(id: id, name: name.isEmpty ? (URL(string: url)?.host ?? url) : name, url: url, date: Date()), at: 0)
            requests = Array(list.prefix(50))
            Store.requests = requests
        }
    }

    /// Asks the Studio what happened to each saved request. Offline: keeps what the phone already knows.
    func refreshRequests() async {
        guard let states = try? await API.requestStates(ids: requests.map(\.id)) else { return }
        var list = requests
        for i in list.indices {
            if let s = states.first(where: { $0.id == list[i].id }) { list[i].status = s.status; list[i].slug = s.slug }
        }
        requests = list
        Store.requests = list
        if states.contains(where: { $0.status == "added" }) { await loadMosques() }
    }

    func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeIn(duration: 0.25)) { if toast == text { toast = nil } }
        }
    }
}
