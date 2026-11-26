import SwiftUI
import CoreLocation
import Shared

/// One-shot "where am I" for distances. Only asks when the user taps; reads quietly when already allowed.
@MainActor
final class UserLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var status: CLAuthorizationStatus
    private let manager = CLLocationManager()

    override init() {
        status = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        refreshIfAllowed()
    }

    var allowed: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }

    func requestAccess() {
        if status == .notDetermined { manager.requestWhenInUseAuthorization() } else { refreshIfAllowed() }
    }
    func refreshIfAllowed() { if allowed { manager.requestLocation() } }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let s = m.authorizationStatus
        Task { @MainActor in self.status = s; self.refreshIfAllowed() }
    }
    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        Task { @MainActor in self.coordinate = c }
    }
    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}
}

struct MasjidsView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var loc = UserLocation()
    @State private var city = "All"
    @State private var query = ""
    @State private var path: [Mosque] = []
    @State private var showAdd = false
    @State private var pendingDefault: Mosque?
    @State private var mapsFor: Mosque?
    private static let visibleChips = 4

    private var cities: [String] { Directory.cities(app.mosques) }
    private var shown: [Mosque] { Directory.filter(app.mosques, city: city, query: query) }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if let msg = app.mosquesMessage, !app.mosques.isEmpty { Text(msg).font(.footnote).foregroundStyle(.orange).padding(.vertical, 6) }
                        if app.mosques.isEmpty {
                            emptyText(app.loadingMosques ? "Loading masjids…" : (app.mosquesMessage ?? "No masjids yet."))
                        } else if shown.isEmpty {
                            emptyText(query.isEmpty ? "No masjids in \(city) yet." : "No masjids match “\(query)”.")
                        }
                        VStack(spacing: 0) {
                            ForEach(shown) { m in
                                row(m)
                                Divider().overlay(Palette.line)
                            }
                        }
                        if loc.status == .notDetermined && !shown.isEmpty {
                            Button { Haptics.tap(); loc.requestAccess() } label: { Label("Show how far each masjid is", systemImage: "location") }
                                .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.teal).padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 24)
                }
                .refreshable { await app.loadMosques() }
                .tabBarClearance()
            }
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Mosque.self) { MasjidDetailView(mosque: $0) }
            .overlay { if let m = pendingDefault { confirm(m) } }
            .sheet(isPresented: $showAdd) { AddMasjidSheet() }
            .sheet(item: $mapsFor) { MapsSheet(mosque: $0) }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 17)).foregroundStyle(Palette.muted)
                    TextField("Search masjids...", text: $query).submitLabel(.search).autocorrectionDisabled()
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) } }
                }
                .font(.system(size: 16))
                .padding(.horizontal, 14).frame(height: 50)
                .background(Capsule().fill(Palette.surface))

                Button { Haptics.tap(); showAdd = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle").font(.system(size: 17))
                        Text("Add new").font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Palette.teal).padding(.horizontal, 13).frame(height: 50)
                    .background(Capsule().fill(Palette.tealSoft))
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    chip("All")
                    ForEach(cities.prefix(Self.visibleChips), id: \.self) { chip($0) }
                    if cities.count > Self.visibleChips {
                        Menu {
                            ForEach(cities.dropFirst(Self.visibleChips), id: \.self) { c in Button(c) { city = c } }
                        } label: {
                            HStack(spacing: 4) { Text("More"); Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)) }
                                .font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.text)
                                .padding(.horizontal, 18).padding(.vertical, 10).background(Capsule().fill(Palette.surface))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 10).padding(.bottom, 10)
    }

    private func chip(_ c: String) -> some View {
        Button { Haptics.tap(); withAnimation(.easeInOut(duration: 0.2)) { city = c } } label: {
            Text(c).font(.system(size: 17, weight: .medium))
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill(city == c ? Palette.teal : Palette.surface))
                .foregroundStyle(city == c ? Color.white : Palette.text)
        }
    }

    // MARK: Rows

    private func distance(_ m: Mosque) -> String? {
        guard let c = loc.coordinate, let lat = m.lat, let lon = m.lon else { return nil }
        return Directory.distanceText(Directory.miles(fromLat: c.latitude, lon: c.longitude, toLat: lat, lon: lon))
    }

    /// "M14 4HY" or "M14 4HY · 0.4 mi". Short on purpose: the full address is on the masjid's own page.
    private func detailLine(_ m: Mosque) -> String {
        [m.shortLine, distance(m)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func row(_ m: Mosque) -> some View {
        let isDefault = app.usingMasjid && m.slug == app.defaultSlug
        return HStack(alignment: .center, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                MasjidLogo(mosque: m, size: 76)
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.name).font(.system(size: 21, weight: .bold)).foregroundStyle(Palette.text).multilineTextAlignment(.leading).lineLimit(2)
                    Text(Directory.cityOf(m)).font(.system(size: 17)).foregroundStyle(Palette.text.opacity(0.85)).lineLimit(1)
                    let d = detailLine(m)
                    if !d.isEmpty { Text(d).font(.system(size: 15)).foregroundStyle(Palette.muted).lineLimit(1) }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { path.append(m) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)

            HStack(spacing: 8) {
                Button { Haptics.tap(); mapsFor = m } label: {
                    Image(systemName: "location").font(.system(size: 19)).foregroundStyle(Palette.teal)
                        .frame(width: 46, height: 46).background(Circle().fill(Palette.tealSoft))
                }
                .accessibilityLabel("Open \(m.name) in Maps")
                Button { Haptics.tap(); if !isDefault { pendingDefault = m } } label: {
                    Image(systemName: isDefault ? "star.fill" : "star").font(.system(size: 21))
                        .foregroundStyle(isDefault ? Palette.gold : Palette.text.opacity(0.7))
                        .frame(width: 46, height: 46).background(Circle().fill(isDefault ? Palette.gold.opacity(0.16) : Palette.surface))
                }
                .accessibilityLabel(isDefault ? "Default masjid" : "Set \(m.name) as default")
            }
        }
        .padding(.vertical, 14)
    }

    private func emptyText(_ s: String) -> some View {
        Text(s).foregroundStyle(Palette.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 50)
    }

    // MARK: Confirm default

    private func confirm(_ m: Mosque) -> some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea().onTapGesture { pendingDefault = nil }
            VStack(spacing: 22) {
                Text(app.usingMasjid ? "Set as default masjid?" : "Change prayer times to this masjid?").font(.system(size: 24, weight: .bold)).multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    MasjidLogo(mosque: m, size: 70)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(m.name).font(.system(size: 20, weight: .bold))
                        Text([Directory.cityOf(m), m.shortLine].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 15)).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                }
                if !app.usingMasjid {
                    Text("Home and your widgets will show this masjid's timetable instead of local prayer times.")
                        .font(.system(size: 16)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                }
                HStack(spacing: 12) {
                    Button(app.usingMasjid ? "Cancel" : "No") { pendingDefault = nil }.buttonStyle(SoftButtonStyle())
                    Button(app.usingMasjid ? "Set as default" : "Yes") {
                        pendingDefault = nil
                        Task { await app.setDefault(m) }
                    }.buttonStyle(TealButtonStyle())
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Palette.bg))
            .padding(.horizontal, 22)
        }
        .transition(.opacity)
    }
}

struct DefaultBadge: View {
    var body: some View {
        Text("Default").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.coral)
            .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(Palette.coralSoft))
    }
}

/// "Open in Maps" bottom sheet: Google Maps, Apple Maps, Waze.
struct MapsSheet: View {
    let mosque: Mosque
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Image(systemName: "location").font(.system(size: 22)).foregroundStyle(Palette.coral)
                    .frame(width: 54, height: 54).background(Circle().fill(Palette.coralSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open in Maps").font(.system(size: 24, weight: .bold))
                    Text("Get directions to \(mosque.name)").font(.system(size: 16)).foregroundStyle(Palette.muted).lineLimit(2)
                }
                Spacer(minLength: 0)
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 18)).foregroundStyle(Palette.text).frame(width: 40, height: 40) }
                    .accessibilityLabel("Close")
            }
            .padding(.bottom, 8)
            mapRow("Google Maps", icon: "mappin.circle.fill", tint: Color(hex: 0x34A853), url: MapLinks.google(mosque))
            Divider().overlay(Palette.line)
            mapRow("Apple Maps", icon: "map.fill", tint: Color(hex: 0x2F8CF0), url: MapLinks.apple(mosque))
            Divider().overlay(Palette.line)
            mapRow("Waze", icon: "car.fill", tint: Color(hex: 0x33CCFF), url: MapLinks.waze(mosque))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22).padding(.top, 24)
        .background(Palette.bg.ignoresSafeArea())
        .presentationDetents([.height(410)])
        .presentationDragIndicator(.visible)
    }

    private func mapRow(_ title: String, icon: String, tint: Color, url: URL?) -> some View {
        Button {
            Haptics.tap()
            if let url { openURL(url) }
            dismiss()
        } label: {
            HStack(spacing: 18) {
                Image(systemName: icon).font(.system(size: 26)).foregroundStyle(tint).frame(width: 52)
                Text(title).font(.system(size: 21, weight: .medium)).foregroundStyle(Palette.text)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 17)).foregroundStyle(Palette.coral)
            }
            .padding(.vertical, 14).contentShape(Rectangle())
        }
        .disabled(url == nil)
    }
}

struct MasjidDetailView: View {
    @EnvironmentObject var app: AppState
    let mosque: Mosque
    @Environment(\.dismiss) private var dismiss
    @State private var showMaps = false
    @State private var askSwitch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    MasjidLogo(mosque: mosque, size: 72)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mosque.name).font(.system(size: 27, weight: .bold))
                        Text(mosque.addressLine).font(.system(size: 15)).foregroundStyle(Palette.muted)
                        if app.usingMasjid && mosque.slug == app.defaultSlug { DefaultBadge() }
                    }
                }
                if let day = app.days[mosque.slug] {
                    TimelineView(.periodic(from: Date(), by: 30)) { ctx in
                        VStack(spacing: 16) {
                            if !TimeLogic.isToday(day, now: ctx.date) { OldTimesBanner(day: day) }
                            TimetableView(day: day, now: ctx.date)
                            FreshnessFooter(day: day, note: app.dayNotes[mosque.slug], now: ctx.date)
                        }
                    }
                } else {
                    Text(app.dayNotes[mosque.slug] ?? "Loading times…").foregroundStyle(Palette.muted)
                }
                Button { showMaps = true } label: { Label("Open in Maps", systemImage: "location") }.buttonStyle(SoftButtonStyle())
                if app.usingMasjid && mosque.slug == app.defaultSlug {
                    Button("Default masjid") {}.buttonStyle(TealButtonStyle(enabled: false)).disabled(true)
                } else {
                    Button("Set as Default") {
                        if app.usingMasjid { Task { await app.setDefault(mosque) } } else { askSwitch = true }
                    }.buttonStyle(TealButtonStyle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 130)   // clears the floating tab bar
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { Haptics.tap(); dismiss() } label: { RoundIcon(system: "chevron.left", size: 44) }.accessibilityLabel("Back")
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 6)
        }
        .background(Palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showMaps) { MapsSheet(mosque: mosque) }
        .alert("Change prayer times to this masjid?", isPresented: $askSwitch) {
            Button("No", role: .cancel) {}
            Button("Yes") { Task { await app.setDefault(mosque) } }
        } message: { Text("Home and your widgets will show this masjid's timetable instead of local prayer times.") }
        .task { await app.loadDay(mosque.slug) }
        .refreshable { await app.loadDay(mosque.slug) }
    }
}
