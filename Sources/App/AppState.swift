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
        guard let slug = defaultSlug else { return }
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
        defaultSlug = m.slug
        Haptics.success()
        showToast("\(m.name) is now your default")
        WidgetCenter.shared.reloadAllTimelines()
        await loadDay(m.slug)
        await Planner.reschedule(for: days[m.slug])
    }

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
