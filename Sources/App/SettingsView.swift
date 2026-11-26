import SwiftUI
import StoreKit
import Shared

private let site = "https://prayer-widgets-studio.vercel.app"

struct SettingsView: View {
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject var app: AppState
    @State private var notifOn = Store.notifyPrayers || Store.notifySunrise

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    private var done: Int { [app.prayerTimesSummary != nil, app.place != nil, notifOn].filter { $0 }.count }

    var body: some View {
        NavigationStack {
            List {
                if done < 3 {
                    Section { setupCard }
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section("Personal setup") {
                    NavigationLink { PrayerTimesSettings() } label: { setupRow("dome", "Prayer times", app.prayerTimesSummary) }
                    NavigationLink { LocationSettings() } label: { setupRow("location", "Location", app.place.map { LocalTimes.shortName($0) }) }
                    NavigationLink { NotificationsView() } label: { setupRow("bell", "Notifications", notifOn ? "On" : nil) }
                }
                Section("General") {
                    Link(destination: URL(string: "\(site)/support")!) { Label("Send feedback", systemImage: "bubble.left").foregroundStyle(Palette.text) }
                    Button { requestReview() } label: { Label("Rate the app", systemImage: "star").foregroundStyle(Palette.text) }
                    NavigationLink { FAQView() } label: { Label("FAQ", systemImage: "questionmark.circle") }
                    Link(destination: URL(string: "\(site)/privacy")!) { Label("Privacy policy", systemImage: "hand.raised").foregroundStyle(Palette.text) }
                    Link(destination: URL(string: "\(site)/terms")!) { Label("Terms of use", systemImage: "doc.text").foregroundStyle(Palette.text) }
                    HStack { Label("About", systemImage: "info.circle"); Spacer(); Text(version).foregroundStyle(Palette.muted) }
                }
            }
            .foregroundStyle(Palette.text)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden).tabBarClearance()
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { notifOn = Store.notifyPrayers || Store.notifySunrise }
        }
    }

    private var setupCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Palette.tealSoft, lineWidth: 9)
                Circle().trim(from: 0, to: CGFloat(done) / 3).stroke(Palette.teal, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(done) of 3").font(.system(size: 17, weight: .bold))
            }
            .frame(width: 84, height: 84)
            Rectangle().fill(Palette.line).frame(width: 1, height: 70)
            VStack(alignment: .leading, spacing: 4) {
                Text("Complete your setup").font(.system(size: 20, weight: .bold))
                Text("Set your prayer times, location and notifications.").font(.system(size: 15)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white))
    }

    private func setupRow(_ icon: String, _ title: String, _ value: String?) -> some View {
        HStack(spacing: 12) {
            Group { if icon == "dome" { DomeGlyph(size: 24) } else { Image(systemName: icon) } }.frame(width: 28).foregroundStyle(Palette.teal)
            Text(title)
            Spacer(minLength: 6)
            if let value { Text(value).foregroundStyle(Palette.muted).lineLimit(1) }
            else { Text("Not set").font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.teal).padding(.horizontal, 12).padding(.vertical, 5).background(Capsule().fill(Palette.tealSoft)) }
        }
    }
}

/// Settings > Prayer times: follow a masjid, or locally calculated times. One fixed calculation method, so no method questions.
struct PrayerTimesSettings: View {
    @EnvironmentObject var app: AppState
    @State private var showPicker = false
    @State private var showLocation = false

    var body: some View {
        List {
            Section {
                Text("Choose how you'd like to get your prayer times.").foregroundStyle(Palette.muted)
            }
            .listRowBackground(Color.clear)
            Section {
                optionRow(selected: app.usingMasjid, title: "My masjid",
                          text: app.defaultMosque?.name ?? "Use the official times from your masjid.", icon: AnyView(DomeGlyph(size: 28))) {
                    if app.defaultSlug != nil { Task { await app.useMasjid() } } else { showPicker = true }
                }
                optionRow(selected: !app.usingMasjid && app.place != nil, title: "Local prayer times",
                          text: "Calculate times for your location.", icon: AnyView(Image(systemName: "location").font(.system(size: 22)))) {
                    if app.place != nil { Task { await app.useLocalTimes() } } else { showLocation = true }
                }
            }
            if app.usingMasjid {
                Section {
                    Button { showPicker = true } label: {
                        HStack { Text("Your masjid"); Spacer(); Text(app.defaultMosque?.name ?? "Not set").foregroundStyle(Palette.muted).lineLimit(1); Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.muted) }
                    }
                }
            } else {
                Section {
                    Toggle(isOn: Binding(get: { app.hanafiAsr }, set: { app.setHanafiAsr($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hanafi Asr")
                            Text("Asr starts later, when a shadow is twice its object's length.").font(.footnote).foregroundStyle(Palette.muted)
                        }
                    }
                    .tint(Palette.teal)
                    NavigationLink { LocationSettings() } label: {
                        HStack { Text("Location"); Spacer(); Text(app.place?.name ?? "Not set").foregroundStyle(Palette.muted) }
                    }
                } footer: {
                    Text("Times are calculated on your phone with the \(LocalTimes.methodName) method. If your masjid's timetable differs, follow your masjid.")
                }
            }
        }
        .foregroundStyle(Palette.text)
        .scrollContentBackground(.hidden).tabBarClearance()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Prayer times").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showPicker) { DefaultPickerSheet() }
        .sheet(isPresented: $showLocation) {
            VStack(spacing: 18) {
                Text("Set your location").font(.system(size: 26, weight: .bold)).padding(.top, 26)
                Text("Local prayer times are calculated for where you are.").foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                LocationChoice(current: app.place) { p in
                    showLocation = false
                    Task { await app.useLocalTimes(place: p) }
                }
                .padding(.horizontal, 22)
                Spacer()
            }
            .background(Palette.bg.ignoresSafeArea())
            .presentationDetents([.medium])
        }
    }

    private func optionRow(selected: Bool, title: String, text: String, icon: AnyView, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon.frame(width: 34).foregroundStyle(Palette.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 18, weight: .semibold))
                    Text(text).font(.footnote).foregroundStyle(Palette.muted).lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 6)
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").font(.system(size: 24)).foregroundStyle(selected ? Palette.teal : Palette.muted.opacity(0.6))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

/// Settings > Location: the place used for local prayer times, nearby masjids and the Qibla.
struct LocationSettings: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Set your location for local prayer times, nearby masjids and Qibla.").font(.system(size: 17)).foregroundStyle(Palette.muted)
            LocationChoice(current: app.place) { p in app.setPlace(p); Haptics.success() }
            HStack(spacing: 14) {
                Image(systemName: "location").font(.system(size: 22)).foregroundStyle(Palette.teal)
                Text(app.place?.name ?? "Not set").font(.system(size: 19, weight: .medium))
                Spacer()
                if app.place != nil { Image(systemName: "checkmark").foregroundStyle(Palette.teal) }
            }
            .padding(.vertical, 8)
            Divider().overlay(Palette.line)
            Spacer()
        }
        .padding(.horizontal, 22).padding(.top, 8)
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Location").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

/// The bell on Home: the same toggles, in a slide-up sheet.
struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notifications").font(.system(size: 24, weight: .bold))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 17)).foregroundStyle(Palette.text).frame(width: 40, height: 40) }
                    .accessibilityLabel("Close")
            }
            .padding(.horizontal, 22).padding(.top, 26)
            NotificationsView(clearTabBar: false)
        }
        .background(Palette.bg.ignoresSafeArea())
        .presentationDetents([.height(470), .large])
        .presentationDragIndicator(.visible)
    }
}

struct NotificationsView: View {
    var clearTabBar = true
    @EnvironmentObject var app: AppState
    @State private var prayers = Store.notifyPrayers
    @State private var sunrise = Store.notifySunrise
    @State private var denied = false

    var body: some View {
        List {
            Section {
                Text("Get an alert when each prayer begins at your prayer times.").foregroundStyle(Palette.muted)
            }
            Section {
                Toggle(isOn: $prayers) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Prayer notifications")
                        Text("Fajr, Dhuhr, Asr, Maghrib, Isha").font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
                Toggle(isOn: $sunrise) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sunrise")
                        Text("An alert at sunrise").font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
            }
            .tint(Palette.teal)
            if denied {
                Section {
                    Text("Notifications are turned off for this app in iPhone Settings.").foregroundStyle(.orange)
                    Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, clearTabBar ? 112 : 0, for: .scrollContent)
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { denied = (await Planner.status()) == .denied && (prayers || sunrise) }
        .onChange(of: prayers) { _, on in Task { await apply(on, isSunrise: false) } }
        .onChange(of: sunrise) { _, on in Task { await apply(on, isSunrise: true) } }
    }

    private func apply(_ on: Bool, isSunrise: Bool) async {
        Haptics.tap()
        if on {
            var s = await Planner.status()
            if s == .notDetermined { _ = await Planner.requestAuthorization(); s = await Planner.status() }
            guard s == .authorized || s == .provisional else {
                denied = true
                if isSunrise { sunrise = false } else { prayers = false }
                return
            }
            denied = false
        }
        if isSunrise { Store.notifySunrise = on } else { Store.notifyPrayers = on }
        await Planner.reschedule(for: app.activeDay())
    }
}

struct FAQView: View {
    private let items: [(String, String)] = [
        ("Where do the times come from?", "If you follow a masjid, from that masjid's own published timetable, which we read and check. If you choose local prayer times, they are calculated on your phone for your location."),
        ("Why do the times differ from other apps?", "Masjids set their own jama'ah times and may use a different method. Local prayer times use the Moonsighting Committee method, which many UK mosques follow, but not all. If they differ, follow your masjid."),
        ("My masjid is missing. What do I do?", "Open the Masjids tab and tap Add new. Search for it, or choose Add manually and send the web address of its timetable. We review every request, and My Requests shows what happened."),
        ("How often do the times update?", "Once a day, early in the morning UK time."),
        ("Why does the widget show yesterday's times early in the morning?", "New times arrive at about 03:30 UTC. Until then the last day's times are shown."),
        ("How do I add the widget?", "Open the Widget tab, then How to. It shows the steps for the home screen and the lock screen."),
        ("Which times do my widgets show?", "Whatever you chose in Settings > Prayer times: your default masjid, or local prayer times. Tap the star next to a masjid in the Masjids tab to follow it. Every widget updates."),
        ("Why are there two lock screen widgets?", "The lock screen is small, so the timetable comes in two halves: Left (Fajr, Sunrise, Dhuhr) and Right (Asr, Maghrib, Isha). Add both side by side."),
        ("Does the app collect my data?", "No account, no ads and no tracking. Your location, or the city you choose, is only used on your phone for the Qibla compass and for distances."),
    ]

    var body: some View {
        List(items, id: \.0) { q, a in
            DisclosureGroup {
                Text(a).foregroundStyle(Palette.muted).padding(.vertical, 4)
            } label: { Text(q).font(.system(size: 16, weight: .semibold)) }
        }
        .scrollContentBackground(.hidden).tabBarClearance()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("FAQ").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
