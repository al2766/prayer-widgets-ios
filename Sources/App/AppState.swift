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
    @Published var themeId: String = Store.themeId
    @Published var layoutId: String = Store.layoutId
    @Published var selectedTab = 0
    @Published var toast: String?
    @Published var bootstrapped = false

    init() {
        if let slug = Store.defaultSlug, let cached = Cache().times(slug: slug) { days[slug] = cached }
    }

    var defaultMosque: Mosque? { mosques.first { $0.slug == defaultSlug } }
    var defaultDay: PrayerResponse? { defaultSlug.flatMap { days[$0] } }
    var theme: WidgetTheme { WidgetTheme.byId(themeId) }
    var layout: WidgetLayout { WidgetLayout.byId(layoutId) }

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

    func setTheme(_ t: WidgetTheme) {
        Store.themeId = t.id; themeId = t.id
        Haptics.success(); showToast("Theme saved. Widgets are updating")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setLayout(_ l: WidgetLayout) {
        Store.layoutId = l.rawValue; layoutId = l.rawValue
        Haptics.success(); showToast("Layout saved. Widgets are updating")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeIn(duration: 0.25)) { if toast == text { toast = nil } }
        }
    }
}
