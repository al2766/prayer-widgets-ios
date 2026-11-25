import Foundation

/// One mosque as listed by GET /api/mosques.
public struct Mosque: Codable, Hashable, Identifiable {
    public let slug: String
    public let name: String
    public let timezone: String
    public let city: String?           // set by the admin; nil shows under "Other"
    public var id: String { slug }
    public init(slug: String, name: String, timezone: String, city: String? = nil) {
        self.slug = slug; self.name = name; self.timezone = timezone; self.city = city
    }
}

public struct MosqueList: Codable {
    public let mosques: [Mosque]
}

/// A set of prayer times. Absent means the mosque does not publish that time; never an empty string.
public struct Times: Codable, Equatable {
    public var fajr: String?
    public var sunrise: String?
    public var dhuhr: String?
    public var asr: String?
    public var maghrib: String?
    public var isha: String?
    public init(fajr: String? = nil, sunrise: String? = nil, dhuhr: String? = nil, asr: String? = nil, maghrib: String? = nil, isha: String? = nil) {
        self.fajr = fajr; self.sunrise = sunrise; self.dhuhr = dhuhr; self.asr = asr; self.maghrib = maghrib; self.isha = isha
    }
}

public struct Freshness: Codable, Equatable {
    public let status: String          // fresh | stale | unknown
    public let ageHours: Double?
    public let lastSuccessAt: String?  // ISO instant of the last validated extraction
    public let lastVerifiedAt: String? // ISO instant of the last successful check
    public init(status: String, ageHours: Double?, lastSuccessAt: String? = nil, lastVerifiedAt: String? = nil) {
        self.status = status; self.ageHours = ageHours; self.lastSuccessAt = lastSuccessAt; self.lastVerifiedAt = lastVerifiedAt
    }
}

/// GET /api/mosques/<slug>/prayer-times
public struct PrayerResponse: Codable, Equatable {
    public let mosque: Mosque
    public let date: String            // yyyy-MM-dd in the mosque's time zone
    public let beginning: Times
    public let jamaah: Times
    public let jamaah2: Times?
    public let jumuah: [String]
    public let freshness: Freshness
}
