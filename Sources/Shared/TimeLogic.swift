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

    // MARK: Display helpers

    public static func parseISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// "Today, 14:58" from the server's real last-check time, in the mosque's zone. nil when the server gave no time.
    public static func updatedText(_ f: Freshness, zoneId: String, now: Date) -> String? {
        guard let iso = f.lastVerifiedAt ?? f.lastSuccessAt, let d = parseISO(iso) else { return nil }
        let zone = TimeZone(identifier: zoneId) ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let tf = DateFormatter()
        tf.locale = Locale(identifier: "en_GB"); tf.timeZone = zone; tf.dateFormat = "HH:mm"
        let time = tf.string(from: d)
        if cal.isDate(d, inSameDayAs: now) { return "Today, \(time)" }
        if let y = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(d, inSameDayAs: y) { return "Yesterday, \(time)" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_GB"); df.timeZone = zone; df.dateFormat = "d MMM"
        return "\(df.string(from: d)), \(time)"
    }

    /// "in 2h 14m", "in 14m", or "in under a minute".
    public static func countdown(to target: Date, from now: Date) -> String {
        let secs = target.timeIntervalSince(now)
        if secs < 60 { return "in under a minute" }
        let m = Int(secs / 60)
        return m >= 60 ? "in \(m / 60)h \(m % 60)m" : "in \(m)m"
    }

    /// "Tue, 25 Nov" in the mosque's zone.
    public static func dayHeading(_ now: Date, zoneId: String) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_GB"); df.timeZone = TimeZone(identifier: zoneId) ?? .current
        df.dateFormat = "EEE, d MMM"
        return df.string(from: now)
    }

    /// True when the data is for today in the mosque's zone.
    public static func isToday(_ r: PrayerResponse, now: Date) -> Bool {
        r.date == dateString(now, zoneId: r.mosque.timezone)
    }
}
