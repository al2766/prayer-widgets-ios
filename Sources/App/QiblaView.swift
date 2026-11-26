import SwiftUI
import CoreLocation
import Shared

/// Location and compass heading. Everything stays on the phone.
final class CompassModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double?              // degrees clockwise from north, nil until the compass reports
    @Published var turn: Double = 0              // same heading but never wraps at 360, so the dial turns the short way
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var status: CLAuthorizationStatus
    @Published var accuracy: Double = -1
    private let manager = CLLocationManager()
    private var running = false                       // true only while the Qibla tab is on screen

    override init() {
        status = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.headingFilter = 1
    }

    var allowed: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }
    var compassAvailable: Bool { CLLocationManager.headingAvailable() }

    func requestAccess() {
        if status == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    func start() {
        running = true
        if allowed { manager.startUpdatingLocation() }
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }
    func stop() { running = false; manager.stopUpdatingLocation(); manager.stopUpdatingHeading() }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        status = m.authorizationStatus
        if running { start() }
    }
    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }
    func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        // True north needs a location fix; without one the magnetic heading is used (a few degrees off in most of the UK).
        let value = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        accuracy = h.headingAccuracy
        if let current = heading { turn += Qibla.difference(value, current.truncatingRemainder(dividingBy: 360)) } else { turn = value }
        heading = value
    }
    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}
    func locationManagerShouldDisplayHeadingCalibration(_ m: CLLocationManager) -> Bool { true }
}

struct QiblaView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var model = CompassModel()
    @State private var place: Place? = Store.qiblaUsesDevice ? nil : Store.place
    @State private var deviceName: String?
    @State private var aligned = false
    @State private var showChooser = false
    @State private var waited = false
    @State private var askedOnce = false

    /// Where the bearing is measured from: the chosen city, else the phone's own position.
    private var origin: (lat: Double, lon: Double)? {
        if let p = place { return (p.lat, p.lon) }
        if let c = model.coordinate { return (c.latitude, c.longitude) }
        return nil
    }
    private var qibla: Double? { origin.map { Qibla.bearing(lat: $0.lat, lon: $0.lon) } }
    private var needle: Double? { qibla.map { $0 - model.turn } }
    private var title: String { place?.name ?? deviceName ?? (model.coordinate != nil ? "My location" : "Set your city") }

    var body: some View {
        VStack(spacing: 0) {
            Button { Haptics.tap(); showChooser = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "location").font(.system(size: 18)).foregroundStyle(Palette.text)
                        .frame(width: 46, height: 46).background(Circle().fill(Palette.surface))
                    Text(title).font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.text)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.text)
                }
                .padding(.horizontal, 20).padding(.top, 14)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)
            if !model.compassAvailable {
                note("No compass on this device", "The Qibla direction needs the iPhone's compass.")
            } else {
                compass
                readout.padding(.top, 26)
                hint.padding(.top, 8)
            }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg.ignoresSafeArea())
        .onAppear {
            guard app.selectedTab == 2 else { return }
            model.start()
            if place == nil && !model.allowed { showChooser = true }      // first visit: ask where to measure from
            Task { try? await Task.sleep(nanoseconds: 3_000_000_000); waited = true }
        }
        .onDisappear { model.stop() }
        // The tab view keeps every tab alive, so start and stop by the chosen tab, not by appear and disappear.
        .onChange(of: app.selectedTab) { _, tab in
            if tab == 2 { model.start() } else { model.stop(); aligned = false }
        }
        .onChange(of: needle) { _, a in
            guard app.selectedTab == 2, let a else { return }
            let on = abs(Qibla.difference(a, 0)) < 3
            if on && !aligned { Haptics.success() }
            withAnimation(.easeInOut(duration: 0.25)) { aligned = on }
        }
        .onChange(of: model.coordinate?.latitude) { _, _ in nameDevicePlace() }
        .onChange(of: app.place) { _, p in if !Store.qiblaUsesDevice { place = p } }
        .sheet(isPresented: $showChooser) {
            ChooseLocationSheet(model: model, current: place) { chosen in
                place = chosen
                Store.qiblaUsesDevice = chosen == nil          // the saved city also drives local prayer times, so it is never erased here
                if let chosen { app.setPlace(chosen) }
                if chosen == nil { nameDevicePlace() }
            }
        }
    }

    // MARK: Compass

    private var compass: some View {
        let size: CGFloat = 316
        let r = size / 2
        return ZStack {
            Circle().fill(aligned ? Palette.mint.opacity(0.13) : Color.white.opacity(0.001))
            // Mosque silhouette watermark.
            DomeShape().fill((aligned ? Palette.mint : Palette.goldDeep).opacity(aligned ? 0.20 : 0.09))
                .frame(width: size * 0.62, height: size * 0.40).offset(y: size * 0.06)

            // The dial turns against the phone, so N always points to true north.
            ZStack {
                Circle().strokeBorder(
                    aligned ? AnyShapeStyle(LinearGradient(colors: [Palette.mint, Palette.mint.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(LinearGradient(colors: [Palette.tealMid, Palette.tealSoft], startPoint: .top, endPoint: .bottom)),
                    lineWidth: 14)
                    .shadow(color: aligned ? Palette.mint.opacity(0.55) : .clear, radius: 14)
                ForEach(0..<72, id: \.self) { i in
                    let major = i % 6 == 0
                    Rectangle().fill(Palette.text.opacity(major ? 0.7 : 0.35))
                        .frame(width: major ? 2 : 1.2, height: major ? 15 : 9)
                        .offset(y: -(r - 30))
                        .rotationEffect(.degrees(Double(i) * 5))
                }
                ForEach([("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)], id: \.0) { letter, deg in
                    Text(letter).font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.text)
                        .rotationEffect(.degrees(-deg + model.turn))          // keep letters upright
                        .offset(y: -(r - 62))
                        .rotationEffect(.degrees(deg))
                }
                if let q = qibla {
                    KaabaBadge()
                        .rotationEffect(.degrees(-q + model.turn))
                        .offset(y: -(r - 46))
                        .rotationEffect(.degrees(q))
                }
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-model.turn))
            .animation(.easeOut(duration: 0.12), value: model.turn)

            // Needle from the centre towards the Qibla.
            ZStack {
                NeedleShape().fill(LinearGradient(colors: [Palette.tealMid, Palette.tealDeep], startPoint: .top, endPoint: .bottom))
                    .frame(width: 26, height: r - 40).offset(y: -(r - 40) / 2 + 2)
                Circle().fill(Color.white).frame(width: 22, height: 22).overlay(Circle().stroke(Palette.tealDeep, lineWidth: 6))
            }
            .rotationEffect(.degrees(needle ?? 0))
            .opacity(needle == nil ? 0.25 : 1)
            .animation(.easeOut(duration: 0.12), value: needle)

            if aligned {
                Image(systemName: "checkmark").font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 64, height: 64).background(Circle().fill(Palette.gold).shadow(color: Palette.gold.opacity(0.5), radius: 12))
                    .offset(y: size * 0.22).transition(.scale.combined(with: .opacity))
            }

            // The phone's own forward marker, fixed at the top.
            Image(systemName: "triangle.fill").font(.system(size: 20)).foregroundStyle(aligned ? Palette.tealDeep : Palette.gold)
                .offset(y: -(r + 22))
        }
        .frame(width: size, height: size + 30)
        .padding(.top, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(qibla.map { "Qibla is \(Int($0.rounded())) degrees from north" + (aligned ? ". You are facing the Qibla." : "") } ?? "Choose a location to find the Qibla")
    }

    private var readout: some View {
        VStack(spacing: 2) {
            Text(qibla.map { "\(Int($0.rounded()))°" } ?? "—").font(.system(size: 64, weight: .bold)).monospacedDigit().foregroundStyle(Palette.text)
            Text("Qibla Direction").font(.system(size: 21)).foregroundStyle(Palette.muted)
        }
    }

    @ViewBuilder private var hint: some View {
        if qibla == nil {
            Text("Choose a city or allow location to find the direction.").font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center).padding(.horizontal, 30)
        } else if model.heading == nil && waited {
            Text("Waiting for the compass. If nothing moves, allow location so the compass can turn on.").font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center).padding(.horizontal, 30)
        } else if model.heading != nil && (model.accuracy < 0 || model.accuracy > 25) {
            Text("Move your phone in a figure of 8 to improve the compass.").font(.footnote).foregroundStyle(.orange)
        } else if model.heading != nil && !model.allowed {
            Text("The compass is using magnetic north. Allow location for a more exact direction.").font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center).padding(.horizontal, 30)
        }
    }

    private func note(_ title: String, _ body: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash").font(.system(size: 36)).foregroundStyle(Palette.muted)
            Text(title).font(.system(size: 22, weight: .bold))
            Text(body).multilineTextAlignment(.center).foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 30)
    }

    /// Names the phone's position ("Manchester, UK") for the header, once.
    private func nameDevicePlace() {
        guard place == nil, let c = model.coordinate, deviceName == nil else { return }
        Task {
            let marks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: c.latitude, longitude: c.longitude))
            if let m = marks?.first, let city = m.locality ?? m.administrativeArea {
                deviceName = ChooseLocationSheet.label(city: city, countryCode: m.isoCountryCode)
            }
        }
    }
}

/// The Kaaba marker: a dark cube on a coral disc.
struct KaabaBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0xF4A08A)).frame(width: 46, height: 46).shadow(color: Palette.coral.opacity(0.35), radius: 6)
            Circle().stroke(Color.white.opacity(0.7), lineWidth: 2).frame(width: 46, height: 46)
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x14181A)).frame(width: 22, height: 20)
            Rectangle().fill(Palette.gold).frame(width: 22, height: 2).offset(y: -4)
        }
    }
}

/// A slim tapered needle pointing up.
struct NeedleShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Choose location

/// "Choose Location": use the phone's location, or pick a city. The choice never leaves the phone.
struct ChooseLocationSheet: View {
    @ObservedObject var model: CompassModel
    let current: Place?
    let onChoose: (Place?) -> Void         // nil = use the phone's location
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var found: [Place] = []
    @State private var searching = false
    @State private var task: Task<Void, Never>?

    static func label(city: String, countryCode: String?) -> String {
        guard let cc = countryCode, !cc.isEmpty else { return city }
        return "\(city), \(cc == "GB" ? "UK" : cc)"
    }

    private var list: [Place] { search.trimmingCharacters(in: .whitespaces).count >= 2 ? found : Place.suggested }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "location").font(.system(size: 22)).foregroundStyle(Palette.goldDeep)
                    .frame(width: 54, height: 54).background(Circle().fill(Palette.coralSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose Location").font(.system(size: 26, weight: .bold))
                    Text("Set your location to get an accurate Qibla direction.").font(.system(size: 16)).foregroundStyle(Palette.muted)
                }
            }
            Button { enable() } label: { Label("Enable Location Access", systemImage: "location.fill") }.buttonStyle(TealButtonStyle())
            Text(model.status == .denied || model.status == .restricted
                 ? "Location is off for this app. Turn it on in iPhone Settings, or choose a city below."
                 : "Use your device's location for automatic, precise direction.")
                .font(.system(size: 15)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField("Search for a city or country", text: $search).autocorrectionDisabled().submitLabel(.search)
                if searching { ProgressView() }
            }
            .font(.system(size: 17)).padding(.horizontal, 16).frame(height: 52).background(Capsule().fill(Palette.surface))

            Text(search.trimmingCharacters(in: .whitespaces).count >= 2 ? "Results" : "Suggested").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.goldDeep).padding(.top, 4)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(list) { p in
                        Button { Haptics.tap(); onChoose(p); dismiss() } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "location").font(.system(size: 16)).foregroundStyle(Palette.goldDeep)
                                    .frame(width: 40, height: 40).background(Circle().fill(Palette.coralSoft))
                                Text(p.name).font(.system(size: 19)).foregroundStyle(Palette.text)
                                Spacer()
                                if current?.name == p.name { Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.goldDeep).frame(width: 36, height: 36).background(Circle().fill(Palette.gold.opacity(0.2))) }
                            }
                            .padding(.vertical, 8).contentShape(Rectangle())
                        }
                        Divider().overlay(Palette.line)
                    }
                    if list.isEmpty && !searching { Text("No place found. Try another spelling.").foregroundStyle(Palette.muted).padding(.top, 20) }
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 26)
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
                let r = await Self.geocode(t)
                if !Task.isCancelled { found = r; searching = false }
            }
        }
        .onChange(of: model.status) { _, s in
            if (s == .authorizedWhenInUse || s == .authorizedAlways) && waitingForPermission { onChoose(nil); dismiss() }
        }
    }

    @State private var waitingForPermission = false

    private func enable() {
        Haptics.tap()
        if model.allowed { onChoose(nil); dismiss(); return }
        if model.status == .denied || model.status == .restricted {
            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
            return
        }
        waitingForPermission = true
        model.requestAccess()
    }

    /// Apple's own place search: free, no key, and the text typed is sent to Apple, not to us.
    static func geocode(_ text: String) async -> [Place] {
        let marks = (try? await CLGeocoder().geocodeAddressString(text)) ?? []
        var seen = Set<String>()
        return marks.compactMap { m -> Place? in
            guard let c = m.location?.coordinate, let city = m.locality ?? m.name else { return nil }
            let name = label(city: city, countryCode: m.isoCountryCode)
            return seen.insert(name).inserted ? Place(name: name, lat: c.latitude, lon: c.longitude) : nil
        }
    }
}
