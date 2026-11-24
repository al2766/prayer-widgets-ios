import Foundation

public enum Prayer: String, CaseIterable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha
    public var title: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
}

public struct Row: Equatable {
    public let prayer: Prayer
    public let begins: String?
    public let jamaah: String?
    /// The time people turn up for: jama'ah when published, otherwise the start.
    public var main: String? { jamaah ?? begins }
}

public enum TimeLogic {
    public static func rows(_ r: PrayerResponse) -> [Row] {
        func pick(_ t: Times, _ p: Prayer) -> String? {
            switch p {
            case .fajr: return t.fajr
            case .sunrise: return t.sunrise
            case .dhuhr: return t.dhuhr
            case .asr: return t.asr
            case .maghrib: return t.maghrib
            case .isha: return t.isha
            }
        }
        return Prayer.allCases.compactMap { p in
            let b = pick(r.beginning, p), j = p == .sunrise ? nil : pick(r.jamaah, p)
            return (b == nil && j == nil) ? nil : Row(prayer: p, begins: b, jamaah: j)
        }
    }

    /// "HH:mm" on a yyyy-MM-dd date in the given zone, or nil when either part is malformed.
    public static func instant(_ hhmm: String, on date: String, zone: TimeZone) -> Date? {
        let t = hhmm.split(separator: ":")
        let d = date.split(separator: "-")
        guard t.count == 2, d.count == 3,
              let h = Int(t[0]), let m = Int(t[1]), let y = Int(d[0]), let mo = Int(d[1]), let da = Int(d[2]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal.date(from: DateComponents(year: y, month: mo, day: da, hour: h, minute: m))
    }

    /// Every prayer (not sunrise) with its moment today, in time order.
    public static func schedule(_ r: PrayerResponse) -> [(row: Row, at: Date)] {
        guard let zone = TimeZone(identifier: r.mosque.timezone) else { return [] }
        return rows(r).compactMap { row in
            guard row.prayer != .sunrise, let t = row.main, let at = instant(t, on: r.date, zone: zone) else { return nil }
            return (row, at)
        }.sorted { $0.at < $1.at }
    }

    /// The next prayer strictly after `now`, or nil when today's are all done.
    public static func next(_ r: PrayerResponse, after now: Date) -> (row: Row, at: Date)? {
        schedule(r).first { $0.at > now }
    }

    /// How old the data is, in plain words, only when it is not fresh.
    public static func staleNote(_ f: Freshness) -> String? {
        guard f.status != "fresh" else { return nil }
        guard let h = f.ageHours else { return "Times not confirmed" }
        return h < 48 ? "Times last checked \(Int(h)) h ago" : "Times last checked \(Int(h / 24)) days ago"
    }

    /// Today's date as yyyy-MM-dd in the given zone.
    public static func dateString(_ now: Date, zoneId: String) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: zoneId) ?? .current
        let c = cal.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
