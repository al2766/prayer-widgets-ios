import Foundation

public enum Qibla {
    /// The Kaaba, Makkah.
    public static let kaabaLat = 21.4225
    public static let kaabaLon = 39.8262

    /// Initial great-circle bearing from a place to the Kaaba, in degrees clockwise from true north (0..<360).
    public static func bearing(lat: Double, lon: Double) -> Double {
        let p1 = lat * .pi / 180, p2 = kaabaLat * .pi / 180
        let dl = (kaabaLon - lon) * .pi / 180
        let y = sin(dl) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Smallest signed angle between two bearings, -180...180.
    public static func difference(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }
}
