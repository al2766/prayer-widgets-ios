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
                                    Text(TimeLogic.dayHeading(ctx.date, zoneId: day.mosque.timezone)).font(.system(size: 20, weight: .regular)).foregroundStyle(Palette.muted)
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
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPicker) { DefaultPickerSheet() }
            .navigationDestination(isPresented: $showBell) { NotificationsView() }
        }
    }

    private func header(_ m: Mosque) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { Haptics.tap(); showPicker = true } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.name).font(.system(size: 31, weight: .bold)).foregroundStyle(Palette.text).multilineTextAlignment(.leading)
                    Text(m.addressLine).font(.system(size: 16)).foregroundStyle(Palette.muted).multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Button { Haptics.tap(); showBell = true } label: { RoundIcon(system: "bell") }.accessibilityLabel("Notifications")
            Button { Haptics.tap(); showMaps = true } label: { RoundIcon(system: "mappin.and.ellipse") }.accessibilityLabel("Open in Maps")
        }
        .sheet(isPresented: $showMaps) { MapsSheet(mosque: m) }
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

/// The deep teal card: next prayer, its time (jama'ah when published), a live countdown and the dome on its hill.
struct NextPrayerCard: View {
    let next: (row: Row, at: Date)
    let now: Date

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Palette.tealMid, Palette.tealDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
            DomeArt(ink: Color(hex: 0xF4EBDD), glow: Palette.turquoise).frame(width: 190, height: 100).offset(x: 6, y: 0)
            VStack(alignment: .leading, spacing: 6) {
                Text("Next Prayer").font(.system(size: 18, weight: .regular)).foregroundStyle(.white.opacity(0.85))
                HStack(alignment: .firstTextBaseline) {
                    Text(next.row.prayer.title).font(.system(size: 42, weight: .bold))
                    Spacer()
                    Text(next.row.main ?? "").font(.system(size: 42, weight: .bold)).monospacedDigit()
                }
                .foregroundStyle(.white)
                Text(TimeLogic.countdown(to: next.at, from: now)).font(.system(size: 21, weight: .semibold)).foregroundStyle(Palette.turquoise)
            }
            .padding(.horizontal, 24).padding(.vertical, 22).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 178)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
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
