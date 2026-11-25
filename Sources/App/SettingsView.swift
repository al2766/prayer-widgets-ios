import SwiftUI
import StoreKit
import Shared

private let site = "https://prayer-widgets-studio.vercel.app"

struct SettingsView: View {
    @Environment(\.requestReview) private var requestReview

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink { NotificationsView() } label: { Label("Notifications", systemImage: "bell") }
                Link(destination: URL(string: "\(site)/support")!) { Label("Send feedback", systemImage: "bubble.left").foregroundStyle(Palette.text) }
                Button { requestReview() } label: { Label("Rate the app", systemImage: "star").foregroundStyle(Palette.text) }
                NavigationLink { FAQView() } label: { Label("FAQ", systemImage: "questionmark.circle") }
                Link(destination: URL(string: "\(site)/privacy")!) { Label("Privacy policy", systemImage: "hand.raised").foregroundStyle(Palette.text) }
                Link(destination: URL(string: "\(site)/terms")!) { Label("Terms of use", systemImage: "doc.text").foregroundStyle(Palette.text) }
                HStack { Label("About", systemImage: "info.circle"); Spacer(); Text(version).foregroundStyle(Palette.muted) }
            }
            .foregroundStyle(Palette.text)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct NotificationsView: View {
    @EnvironmentObject var app: AppState
    @State private var prayers = Store.notifyPrayers
    @State private var sunrise = Store.notifySunrise
    @State private var denied = false

    var body: some View {
        List {
            Section {
                Text("Get an alert when each prayer begins at your default masjid.").foregroundStyle(Palette.muted)
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
            .tint(Palette.amber)
            if denied {
                Section {
                    Text("Notifications are turned off for this app in iPhone Settings.").foregroundStyle(.orange)
                    Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                }
            }
        }
        .scrollContentBackground(.hidden)
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
        await Planner.reschedule(for: app.defaultDay)
    }
}

struct FAQView: View {
    private let items: [(String, String)] = [
        ("Where do the times come from?", "From each masjid's own published timetable. We read it and check it before showing it."),
        ("Why do the times differ from other apps?", "Masjids set their own jama'ah times. We show the masjid's times, not a calculation."),
        ("My masjid is missing. What do I do?", "Open the Masjids tab, tap Request a New Masjid and send the web address of its timetable. We review every request."),
        ("How often do the times update?", "Once a day, early in the morning UK time."),
        ("Why does the widget show yesterday's times early in the morning?", "New times arrive at about 03:30 UTC. Until then the last day's times are shown."),
        ("How do I add the widget?", "Open the Widget tab, then How to Add. Hold your home screen, tap +, search Prayer Widgets and tap Add Widget."),
        ("Does the app collect my data?", "No account, no ads and no tracking. Your location is only used on your phone for the Qibla compass."),
    ]

    var body: some View {
        List(items, id: \.0) { q, a in
            DisclosureGroup {
                Text(a).foregroundStyle(Palette.muted).padding(.vertical, 4)
            } label: { Text(q).font(.system(size: 16, weight: .semibold)) }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("FAQ").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
