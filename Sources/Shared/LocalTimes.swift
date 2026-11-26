import Foundation
import Adhan

/// Prayer times worked out on the phone for a place, used when the user follows "Local prayer times" instead of a masjid.
/// One fixed method: the Moonsighting Committee method (18 degrees for Fajr and Isha, seasonal rules, one-seventh-of-the-night above 55 degrees north).
/// Asr is the standard time unless the user switches on the Hanafi (later) Asr. Nothing here uses the network.
public enum LocalTimes {
    public static let zoneId = "Europe/London"
    public static let slug = "local"
    public static let methodName = "Moonsighting Committee"

    /// "Manchester, UK" becomes "Manchester".
    public static func shortName(_ place: Place) -> String {
        place.name.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? place.name
    }

    /// A stand-in "masjid" for local times, so every screen and widget can show them the same way.
    public static func mosque(for place: Place) -> Mosque {
        Mosque(slug: slug, name: shortName(place), timezone: zoneId, city: shortName(place), lat: place.lat, lon: place.lon)
    }

    /// Today's times for the place, in the same shape the Studio sends for a masjid. Jama'ah is empty: a calculation has none.
    public static func day(place: Place, now: Date, hanafiAsr: Bool) -> PrayerResponse? {
        let zone = TimeZone(identifier: zoneId) ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let comps = cal.dateComponents([.year, .month, .day], from: now)

        var params = CalculationMethod.moonsightingCommittee.params
        params.madhab = hanafiAsr ? .hanafi : .shafi
        guard let t = PrayerTimes(coordinates: Coordinates(latitude: place.lat, longitude: place.lon), date: comps, calculationParameters: params) else { return nil }

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB"); f.timeZone = zone; f.dateFormat = "HH:mm"
        let times = Times(fajr: f.string(from: t.fajr), sunrise: f.string(from: t.sunrise), dhuhr: f.string(from: t.dhuhr),
                          asr: f.string(from: t.asr), maghrib: f.string(from: t.maghrib), isha: f.string(from: t.isha))
        let date = TimeLogic.dateString(now, zoneId: zoneId)
        let nowISO = ISO8601DateFormatter().string(from: now)
        return PrayerResponse(mosque: mosque(for: place), date: date, beginning: times, jamaah: Times(), jamaah2: nil, jumuah: [],
                              freshness: Freshness(status: "fresh", ageHours: 0, lastSuccessAt: nowISO, lastVerifiedAt: nowISO))
    }
}
