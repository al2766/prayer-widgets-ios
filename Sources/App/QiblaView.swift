import SwiftUI
import CoreLocation
import Shared

/// Location and compass heading. Everything stays on the phone.
final class CompassModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double?          // degrees clockwise from north, nil until the compass reports
    @Published var qibla: Double?            // bearing to the Kaaba from here
    @Published var status: CLAuthorizationStatus = .notDetermined
    @Published var accuracy: Double = -1
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.headingFilter = 1
        status = manager.authorizationStatus
    }

    func start() {
        if status == .notDetermined { manager.requestWhenInUseAuthorization() }
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }
    func stop() { manager.stopUpdatingLocation(); manager.stopUpdatingHeading() }

    var compassAvailable: Bool { CLLocationManager.headingAvailable() }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        status = m.authorizationStatus
        start()
    }
    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        qibla = Qibla.bearing(lat: l.coordinate.latitude, lon: l.coordinate.longitude)
    }
    func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        heading = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        accuracy = h.headingAccuracy
    }
    func locationManagerShouldDisplayHeadingCalibration(_ m: CLLocationManager) -> Bool { true }
}

struct QiblaView: View {
    @StateObject private var model = CompassModel()
    @State private var aligned = false

    private var needleAngle: Double? {
        guard let h = model.heading, let q = model.qibla else { return nil }
        return q - h
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            switch model.status {
            case .denied, .restricted:
                message("Location is off", "Allow location to find the Qibla direction. It stays on your phone.", button: true)
            default:
                if !model.compassAvailable {
                    message("No compass on this device", "The Qibla bearing needs the iPhone's compass.", button: false)
                } else {
                    compass
                    readout
                    if model.accuracy < 0 || model.accuracy > 25, model.heading != nil {
                        Text("Move your phone in a figure of 8 to improve the compass.").font(.footnote).foregroundStyle(.orange)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg.ignoresSafeArea())
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: needleAngle) { _, a in
            guard let a else { return }
            let on = abs(Qibla.difference(a, 0)) < 3
            if on && !aligned { Haptics.success() }
            aligned = on
        }
    }

    private var compass: some View {
        let h = model.heading ?? 0
        return ZStack {
            // The dial turns against the phone so N always points to true north.
            ZStack {
                Circle().stroke(Palette.line, lineWidth: 2)
                ForEach(0..<72, id: \.self) { i in
                    Rectangle().fill(i % 18 == 0 ? Palette.text : Palette.muted.opacity(0.6))
                        .frame(width: i % 9 == 0 ? 2 : 1, height: i % 9 == 0 ? 14 : 8)
                        .offset(y: -150 + (i % 9 == 0 ? 7 : 4))
                        .rotationEffect(.degrees(Double(i) * 5))
                }
                ForEach([("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)], id: \.0) { letter, deg in
                    Text(letter).font(.system(size: 20, weight: .semibold)).foregroundStyle(letter == "N" ? Palette.navy : Palette.text)
                        .rotationEffect(.degrees(-deg + h))          // keep letters upright
                        .offset(y: -118)
                        .rotationEffect(.degrees(deg))
                }
                if let q = model.qibla {
                    Image(systemName: "cube.fill").font(.system(size: 20)).foregroundStyle(Palette.amber)
                        .rotationEffect(.degrees(-q + h))
                        .offset(y: -150)
                        .rotationEffect(.degrees(q))
                }
            }
            .frame(width: 300, height: 300)
            .rotationEffect(.degrees(-h))
            .animation(.easeOut(duration: 0.15), value: h)

            Needle().fill(LinearGradient(colors: [Palette.navy, Palette.navy, Palette.amber], startPoint: .top, endPoint: .bottom))
                .frame(width: 70, height: 130)
                .rotationEffect(.degrees(needleAngle ?? 0))
                .opacity(needleAngle == nil ? 0.25 : 1)
                .animation(.easeOut(duration: 0.15), value: needleAngle)
        }
        .frame(width: 320, height: 320)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.qibla.map { "Qibla is \(Int($0.rounded())) degrees from north" } ?? "Finding Qibla")
    }

    private var readout: some View {
        VStack(spacing: 2) {
            Text(model.qibla.map { "\(Int($0.rounded()))°" } ?? "—").font(.system(size: 44, weight: .bold)).monospacedDigit()
            Text(model.qibla == nil ? "Finding your location…" : "From North").foregroundStyle(Palette.muted)
        }
    }

    private func message(_ title: String, _ body: String, button: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash").font(.system(size: 36)).foregroundStyle(Palette.muted)
            Text(title).font(.system(size: 22, weight: .bold))
            Text(body).multilineTextAlignment(.center).foregroundStyle(Palette.muted)
            if button {
                Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }.buttonStyle(NavyButtonStyle())
            }
        }
    }
}

/// A slim arrow pointing up.
struct Needle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.22))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
