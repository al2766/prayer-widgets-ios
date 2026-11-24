import SwiftUI
import Shared

struct MosqueListView: View {
    @State private var mosques: [Mosque] = Cache().mosques()
    @State private var message: String?
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("How to add the widget") { HowToView() }
                }
                Section("Mosques") {
                    if mosques.isEmpty && !loading {
                        Text(message ?? "No mosques yet.").foregroundStyle(.secondary)
                    }
                    ForEach(mosques) { m in
                        NavigationLink(m.name) { MosqueDetailView(mosque: m) }
                    }
                }
            }
            .navigationTitle("Prayer Widgets")
            .overlay { if loading && mosques.isEmpty { ProgressView() } }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let list = try await API.mosques()
            mosques = list
            Cache().saveMosques(list)
            message = nil
        } catch {
            message = mosques.isEmpty ? "Could not load the mosque list. Pull down to try again." : "Offline: showing the last list."
        }
    }
}

struct MosqueDetailView: View {
    let mosque: Mosque
    @State private var day: PrayerResponse?
    @State private var note: String?

    var body: some View {
        List {
            if let day {
                Section(day.date) {
                    ForEach(TimeLogic.rows(day), id: \.prayer) { row in
                        HStack {
                            Text(row.prayer.title)
                            Spacer()
                            VStack(alignment: .trailing) {
                                if let j = row.jamaah { Text(j).font(.headline) }
                                if let b = row.begins { Text(row.jamaah == nil ? b : "starts \(b)").font(row.jamaah == nil ? .headline : .caption).foregroundStyle(row.jamaah == nil ? .primary : .secondary) }
                            }
                        }
                    }
                    ForEach(Array(day.jumuah.enumerated()), id: \.offset) { i, t in
                        HStack { Text(day.jumuah.count > 1 ? "Jumu'ah \(i + 1)" : "Jumu'ah"); Spacer(); Text(t).font(.headline) }
                    }
                }
                if let stale = TimeLogic.staleNote(day.freshness) { Section { Text(stale).foregroundStyle(.orange) } }
            } else if let note {
                Section { Text(note).foregroundStyle(.secondary) }
            }
            Section { NavigationLink("Add this mosque as a widget") { HowToView() } }
        }
        .navigationTitle(mosque.name)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        let cache = Cache()
        do {
            let (d, raw) = try await API.prayerTimes(slug: mosque.slug)
            day = d; note = nil
            cache.saveTimes(raw, slug: mosque.slug)
        } catch API.Failure.http(404) {
            day = cache.times(slug: mosque.slug)
            note = day == nil ? "Today's times are not published yet. Try again later." : nil
        } catch {
            day = cache.times(slug: mosque.slug)
            note = day == nil ? "Could not load the times. Check your connection." : "Offline: showing the last saved times."
        }
    }
}

struct HowToView: View {
    var body: some View {
        List {
            Section("Add the widget") {
                Label("Touch and hold an empty spot on your Home Screen.", systemImage: "1.circle")
                Label("Tap the + button at the top.", systemImage: "2.circle")
                Label("Search for Prayer Widgets and pick a size.", systemImage: "3.circle")
                Label("Tap Add Widget, then touch and hold it and choose Edit Widget to pick your mosque.", systemImage: "4.circle")
            }
        }
        .navigationTitle("Add the widget")
    }
}
