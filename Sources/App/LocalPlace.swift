import SwiftUI
import CoreLocation
import Shared

/// Finds where the phone is, once, and names it ("Manchester, UK"). Asks only when the user taps. Nothing leaves the phone except
/// the lookup of the place name, which Apple's own service does.
@MainActor
final class PlaceFinder: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus
    @Published var busy = false
    @Published var message: String?
    private let manager = CLLocationManager()
    private var onFound: ((Place) -> Void)?

    override init() {
        status = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var denied: Bool { status == .denied || status == .restricted }
    private var allowed: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }

    /// Asks for permission when needed, then finds and names the place. `done` runs once with the result.
    func find(done: @escaping (Place) -> Void) {
        message = nil
        onFound = done
        if denied {
            message = "Location is off for this app. Turn it on in iPhone Settings, or search for a city."
            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
            return
        }
        busy = true
        if status == .notDetermined { manager.requestWhenInUseAuthorization() } else { manager.requestLocation() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let s = m.authorizationStatus
        Task { @MainActor in
            self.status = s
            if self.busy && (s == .authorizedWhenInUse || s == .authorizedAlways) { self.manager.requestLocation() }
            if self.busy && (s == .denied || s == .restricted) { self.busy = false; self.message = "Location is off. Search for a city instead." }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            let marks = try? await CLGeocoder().reverseGeocodeLocation(loc)
            let mark = marks?.first
            let city = mark?.locality ?? mark?.subAdministrativeArea ?? mark?.administrativeArea ?? "My location"
            let name = ChooseLocationSheet.label(city: city, countryCode: mark?.isoCountryCode)
            self.busy = false
            self.onFound?(Place(name: name, lat: loc.coordinate.latitude, lon: loc.coordinate.longitude))
            self.onFound = nil
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.busy = false; self.message = "Could not find your location. Try again, or search for a city." }
    }

    /// Apple's own place search, limited to the UK. Free, no key; the text typed goes to Apple, not to us.
    static func searchUK(_ text: String) async -> [Place] {
        let marks = (try? await CLGeocoder().geocodeAddressString(text.lowercased().contains("uk") ? text : "\(text), UK")) ?? []
        var seen = Set<String>()
        return marks.compactMap { m -> Place? in
            guard m.isoCountryCode == "GB", let c = m.location?.coordinate, let city = m.locality ?? m.name else { return nil }
            let name = ChooseLocationSheet.label(city: city, countryCode: "GB")
            return seen.insert(name).inserted ? Place(name: name, lat: c.latitude, lon: c.longitude) : nil
        }
    }
}

/// "Search for a city": a bottom sheet with a search box and the biggest UK cities. Choosing one saves it and closes the sheet.
struct CitySheet: View {
    let current: Place?
    let onChoose: (Place) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var found: [Place] = []
    @State private var searching = false
    @State private var task: Task<Void, Never>?

    private var typed: Bool { search.trimmingCharacters(in: .whitespaces).count >= 2 }
    private var list: [Place] { typed ? found : Place.suggested }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Search for a city").font(.system(size: 26, weight: .bold))
                Text("Select a city to set your location.").font(.system(size: 16)).foregroundStyle(Palette.muted)
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField("Search for a city", text: $search).autocorrectionDisabled().submitLabel(.search)
                if searching { ProgressView() }
            }
            .font(.system(size: 17)).padding(.horizontal, 16).frame(height: 52)
            .background(Capsule().fill(Color.white).overlay(Capsule().stroke(Palette.line)))

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(list) { p in
                        Button { Haptics.tap(); onChoose(p); dismiss() } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "location").font(.system(size: 18)).foregroundStyle(Palette.teal).frame(width: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(LocalTimes.shortName(p)).font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.text)
                                    Text("United Kingdom").font(.system(size: 15)).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                if current?.name == p.name { Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.teal) }
                            }
                            .padding(.vertical, 10).contentShape(Rectangle())
                        }
                        Divider().overlay(Palette.line)
                    }
                    if typed && found.isEmpty && !searching {
                        Text("No UK place found. Try another spelling.").foregroundStyle(Palette.muted).padding(.top, 20)
                    }
                }
            }
            Label("Selecting a city saves it immediately and closes this sheet.", systemImage: "info.circle")
                .font(.system(size: 15)).foregroundStyle(Palette.text.opacity(0.8))
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.tealSoft.opacity(0.7)))
        }
        .padding(.horizontal, 22).padding(.top, 26).padding(.bottom, 10)
        .background(Palette.bg.ignoresSafeArea())
        .presentationDetents([.large, .fraction(0.75)])
        .presentationDragIndicator(.visible)
        .onChange(of: search) { _, q in
            task?.cancel()
            let t = q.trimmingCharacters(in: .whitespaces)
            guard t.count >= 2 else { found = []; searching = false; return }
            searching = true
            task = Task {
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled else { return }
                let r = await PlaceFinder.searchUK(t)
                if !Task.isCancelled { found = r; searching = false }
            }
        }
    }
}

/// The two ways to set a location, used in onboarding and in Settings: "Use my location" and "Search for a city".
struct LocationChoice: View {
    let current: Place?
    let onPlace: (Place) -> Void
    @StateObject private var finder = PlaceFinder()
    @State private var showCities = false

    var body: some View {
        VStack(spacing: 12) {
            Button { Haptics.tap(); finder.find(done: onPlace) } label: {
                HStack(spacing: 10) {
                    if finder.busy { ProgressView().tint(Palette.teal) } else { Image(systemName: "location.fill") }
                    Text("Use my location")
                }
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.teal)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(Palette.tealSoft))
            }
            Button { Haptics.tap(); showCities = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    Text("Search for a city")
                    Spacer()
                }
                .font(.system(size: 17)).foregroundStyle(Palette.muted)
                .padding(.horizontal, 18).frame(minHeight: 54)
                .background(Capsule().fill(Color.white).overlay(Capsule().stroke(Palette.line)))
            }
            if let m = finder.message { Text(m).font(.system(size: 14)).foregroundStyle(.orange).multilineTextAlignment(.center) }
        }
        .sheet(isPresented: $showCities) { CitySheet(current: current, onChoose: onPlace) }
    }
}
