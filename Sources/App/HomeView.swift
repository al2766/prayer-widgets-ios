import SwiftUI
import Shared

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @State private var showPicker = false
    @State private var showMaps = false
    @State private var showBell = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let m = app.defaultMosque ?? app.defaultSlug.flatMap({ s in app.days[s].map { $0.mosque } }) {
                        header(m)
                        if let day = app.days[m.slug] {
                            TimelineView(.periodic(from: Date(), by: 15)) { ctx in
                                VStack(alignment: .leading, spacing: 20) {
                                    HStack(spacing: 12) {
                                        Text(TimeLogic.dayHeading(ctx.date, zoneId: day.mosque.timezone)).font(.system(size: 21, weight: .regular)).foregroundStyle(Palette.muted)
                                        Spacer(minLength: 0)
                                        Button { Haptics.tap(); showBell = true } label: { RoundIcon(system: "bell", size: 56) }.accessibilityLabel("Notifications")
                                        Button { Haptics.tap(); showMaps = true } label: { RoundIcon(system: "location", size: 56) }.accessibilityLabel("Open in Maps")
                                    }
                                    if !TimeLogic.isToday(day, now: ctx.date) { OldTimesBanner(day: day) }
                                    if let n = TimeLogic.next(day, after: ctx.date), TimeLogic.isToday(day, now: ctx.date) { NextPrayerCard(next: n, now: ctx.date) }
                                    TimetableView(day: day, now: ctx.date)
                                    FreshnessFooter(day: day, note: app.dayNotes[m.slug], now: ctx.date)
                                }
                            }
                        } else {
                            Text(app.dayNotes[m.slug] ?? "Loading times…").foregroundStyle(Palette.muted).padding(.top, 20)
                        }
                    } else {
                        empty
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 24)
            }
            .refreshable { await app.refreshDefault() }
            .tabBarClearance()
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPicker) { DefaultPickerSheet() }
            .sheet(isPresented: $showMaps) { if let m = app.defaultMosque { MapsSheet(mosque: m) } }
            .navigationDestination(isPresented: $showBell) { NotificationsView() }
        }
    }

    private func header(_ m: Mosque) -> some View {
        Button { Haptics.tap(); showPicker = true } label: {
            HStack(alignment: .center, spacing: 16) {
                MasjidLogo(mosque: m, size: 84)
                VStack(alignment: .leading, spacing: 5) {
                    Text(m.name).font(.system(size: 33, weight: .bold)).foregroundStyle(Palette.text)
                        .multilineTextAlignment(.leading).lineLimit(2).minimumScaleFactor(0.75)
                    Text(m.addressLine).font(.system(size: 16)).foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.leading).lineLimit(2).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "building.columns").font(.system(size: 40)).foregroundStyle(Palette.teal)
            Text("Choose your masjid").font(.system(size: 22, weight: .bold))
            Text("Pick a default masjid to see its prayer times here and in your widgets.").multilineTextAlignment(.center).foregroundStyle(Palette.muted)
            Button("Browse masjids") { app.selectedTab = 1 }.buttonStyle(TealButtonStyle())
        }
        .padding(.top, 80)
    }
}

/// The deep teal card: next prayer, its start and jama'ah times, a live countdown, and a sunrise over the dome.
struct NextPrayerCard: View {
    let next: (row: Row, at: Date)
    let now: Date

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [Palette.tealMid, Palette.tealDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
            SunriseArt().frame(width: 230, height: 104)
            VStack(alignment: .leading, spacing: 8) {
                Text("Next Prayer").font(.system(size: 19, weight: .regular)).foregroundStyle(.white.opacity(0.9))
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(next.row.prayer.title).font(.system(size: 44, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                        Text(TimeLogic.countdown(to: next.at, from: now)).font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.turquoise).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .layoutPriority(1)
                    Rectangle().fill(Color.white.opacity(0.28)).frame(width: 1, height: 74).padding(.top, 4)
                    HStack(spacing: 16) {
                        timeColumn("Start", next.row.begins)
                        timeColumn("Jama'ah", next.row.jamaah ?? next.row.main)
                    }
                }
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 24).padding(.vertical, 22).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func timeColumn(_ title: String, _ t: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 17, weight: .regular)).foregroundStyle(.white.opacity(0.9))
            Text(t ?? "–").font(.system(size: 31, weight: .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

/// Warm sun rising behind a dome and a minaret, over two teal hills.
struct SunriseArt: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(LinearGradient(colors: [Color(hex: 0xF6B28A), Color(hex: 0xE98B62)], startPoint: .top, endPoint: .bottom))
                    .frame(width: h * 1.05, height: h * 1.05).offset(x: -w * 0.30, y: h * 0.42)
                HillsShape().fill(Palette.tealMid.opacity(0.75)).frame(width: w, height: h * 0.62)
                HillsShape().fill(Palette.tealDeep.opacity(0.9)).frame(width: w * 0.9, height: h * 0.4)
                VStack(spacing: 0) {
                    Circle().fill(Color(hex: 0x1D8F86)).frame(width: 7, height: 7)
                    Capsule().fill(Color(hex: 0x1D8F86)).frame(width: 5, height: 14)
                    Rectangle().fill(Color(hex: 0x1D8F86)).frame(width: 11, height: 30)
                }
                .offset(x: -w * 0.03, y: -h * 0.20)
                DomeShape().fill(Color(hex: 0x1D8F86)).frame(width: w * 0.24, height: w * 0.14).offset(x: -w * 0.16, y: -h * 0.17)
            }
            .frame(width: w, height: h, alignment: .bottomTrailing)
        }
        .allowsHitTesting(false)
    }
}

/// Tap the name to switch the default masjid.
struct DefaultPickerSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(app.mosques) { m in
                Button {
                    Task { await app.setDefault(m); dismiss() }
                } label: {
                    HStack(spacing: 12) {
                        MasjidLogo(mosque: m, size: 44)
                        VStack(alignment: .leading) { Text(m.name).foregroundStyle(Palette.text); Text(m.addressLine).font(.caption).foregroundStyle(Palette.muted) }
                        Spacer()
                        if m.slug == app.defaultSlug { Image(systemName: "checkmark").foregroundStyle(Palette.teal) }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Default masjid").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
