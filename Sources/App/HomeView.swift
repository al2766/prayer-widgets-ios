import SwiftUI
import Shared

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let m = app.defaultMosque ?? app.defaultSlug.flatMap({ s in app.days[s].map { $0.mosque } }) {
                        header(m)
                        if let day = app.days[m.slug] {
                            TimelineView(.periodic(from: Date(), by: 15)) { ctx in
                                VStack(alignment: .leading, spacing: 18) {
                                    Text(TimeLogic.dayHeading(ctx.date, zoneId: day.mosque.timezone)).font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.muted)
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
        }
    }

    private func header(_ m: Mosque) -> some View {
        Button { Haptics.tap(); showPicker = true } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.name).font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.text).multilineTextAlignment(.leading)
                    Text([m.city, "UK"].compactMap { $0 }.joined(separator: ", ")).font(.system(size: 15)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
            }
        }
        .buttonStyle(.plain)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "building.columns").font(.system(size: 40)).foregroundStyle(Palette.amber)
            Text("Choose your masjid").font(.system(size: 22, weight: .bold))
            Text("Pick a default masjid to see its prayer times here and in your widgets.").multilineTextAlignment(.center).foregroundStyle(Palette.muted)
            Button("Browse masjids") { app.selectedTab = 1 }.buttonStyle(NavyButtonStyle())
        }
        .padding(.top, 80)
    }
}

/// The warm amber card: next prayer, its time (jama'ah when published) and a live countdown.
struct NextPrayerCard: View {
    let next: (row: Row, at: Date)
    let now: Date

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LinearGradient(colors: [Palette.amberSoft, Palette.amber], startPoint: .topLeading, endPoint: .bottomTrailing))
            // A soft arch curve, as in the mockup.
            Circle().fill(Color.white.opacity(0.18)).frame(width: 150, height: 150).offset(x: 40, y: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text("Next Prayer").font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.navy.opacity(0.75))
                HStack(alignment: .firstTextBaseline) {
                    Text(next.row.prayer.title).font(.system(size: 36, weight: .bold))
                    Spacer()
                    Text(next.row.main ?? "").font(.system(size: 36, weight: .bold)).monospacedDigit()
                }
                Text(TimeLogic.countdown(to: next.at, from: now)).font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(Palette.navy)
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Tap the header to switch the default masjid.
struct DefaultPickerSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(app.mosques) { m in
                Button {
                    Task { await app.setDefault(m); dismiss() }
                } label: {
                    HStack {
                        VStack(alignment: .leading) { Text(m.name).foregroundStyle(Palette.text); if let c = m.city { Text(c).font(.caption).foregroundStyle(Palette.muted) } }
                        Spacer()
                        if m.slug == app.defaultSlug { Image(systemName: "checkmark").foregroundStyle(Palette.amber) }
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
