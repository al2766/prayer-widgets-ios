import Foundation

/// A place the user can pick instead of sharing their location (used for the Qibla direction).
public struct Place: Codable, Equatable, Hashable, Identifiable {
    public let name: String            // "Manchester, UK"
    public let lat: Double
    public let lon: Double
    public var id: String { name }
    public init(name: String, lat: Double, lon: Double) { self.name = name; self.lat = lat; self.lon = lon }

    /// Shown first in "Choose Location". Centre-of-city coordinates, plenty accurate for a Qibla bearing.
    public static let suggested: [Place] = [
        Place(name: "Manchester, UK", lat: 53.4808, lon: -2.2426),
        Place(name: "London, UK", lat: 51.5074, lon: -0.1278),
        Place(name: "Birmingham, UK", lat: 52.4862, lon: -1.8904),
        Place(name: "Leeds, UK", lat: 53.8008, lon: -1.5491),
        Place(name: "Glasgow, UK", lat: 55.8642, lon: -4.2518),
    ]
}

/// Pure helpers for the masjid list: filters, distance, map links.
public enum Directory {
    public static let country = "United Kingdom"
    public static let other = "Other"

    public static func cityOf(_ m: Mosque) -> String { (m.city?.isEmpty == false ? m.city : nil) ?? other }

    /// City names, sorted, with "Other" last when some masjid has no city.
    public static func cities(_ list: [Mosque]) -> [String] {
        let set = Set(list.map(cityOf))
        return set.filter { $0 != other }.sorted() + (set.contains(other) ? [other] : [])
    }

    /// Areas inside one city (or all cities when nil), sorted.
    public static func areas(_ list: [Mosque], city: String?) -> [String] {
        let inCity = list.filter { city == nil || cityOf($0) == city }
        return Set(inCity.compactMap { $0.area }.filter { !$0.isEmpty }).sorted()
    }

    /// Filters by city, area and a search word that may match the name, city, area, address or postcode.
    public static func filter(_ list: [Mosque], city: String? = nil, area: String? = nil, query: String = "") -> [Mosque] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return list.filter { m in
            if let city, city != "All", cityOf(m) != city { return false }
            if let area, m.area != area { return false }
            if q.isEmpty { return true }
            return [m.name, cityOf(m), m.area ?? "", m.address ?? ""].contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    /// Straight-line distance in miles between two points (haversine).
    public static func miles(fromLat a: Double, lon b: Double, toLat c: Double, lon d: Double) -> Double {
        let r = 3958.8
        let p1 = a * .pi / 180, p2 = c * .pi / 180
        let dp = (c - a) * .pi / 180, dl = (d - b) * .pi / 180
        let h = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }

    /// "0.4 mi", "12 mi".
    public static func distanceText(_ miles: Double) -> String {
        miles < 10 ? String(format: "%.1f mi", miles) : "\(Int(miles.rounded())) mi"
    }
}

/// Links that open a masjid in a maps app. Plain web links: they open the app when it is installed, else the website.
public enum MapLinks {
    private static func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=#"))) ?? s }

    private static func query(_ m: Mosque) -> String {
        if let lat = m.lat, let lon = m.lon { return "\(lat),\(lon)" }
        return [m.name, m.address].compactMap { $0 }.joined(separator: ", ")
    }

    public static func apple(_ m: Mosque) -> URL? {
        var s = "https://maps.apple.com/?q=\(enc(m.name))"
        if let lat = m.lat, let lon = m.lon { s += "&ll=\(lat),\(lon)" } else if let a = m.address { s += "&address=\(enc(a))" }
        return URL(string: s)
    }
    public static func google(_ m: Mosque) -> URL? {
        URL(string: "https://www.google.com/maps/search/?api=1&query=\(enc(query(m)))")
    }
    public static func waze(_ m: Mosque) -> URL? {
        if let lat = m.lat, let lon = m.lon { return URL(string: "https://waze.com/ul?ll=\(lat),\(lon)&navigate=yes") }
        return URL(string: "https://waze.com/ul?q=\(enc(query(m)))&navigate=yes")
    }
}

/// What the phone remembers about a "please add this masjid" request, so "My Requests" can show what happened.
public struct SavedRequest: Codable, Identifiable, Equatable {
    public let id: String              // returned by the Studio
    public let name: String
    public let url: String
    public let date: Date
    public var status: String          // received | added | closed
    public var slug: String?
    public init(id: String, name: String, url: String, date: Date, status: String = "received", slug: String? = nil) {
        self.id = id; self.name = name; self.url = url; self.date = date; self.status = status; self.slug = slug
    }
}

/// Tidies the web address a user types when asking for a masjid to be added.
public enum RequestURL {
    /// Accepts "https://…" or "http://…". A bare "example.org/times" gets https:// added. nil when it cannot be a real website address.
    public static func clean(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.contains(" ") else { return nil }
        let full = t.contains("://") ? t : "https://\(t)"
        guard let u = URL(string: full), let scheme = u.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = u.host, host.contains(".") else { return nil }
        return full
    }
}
