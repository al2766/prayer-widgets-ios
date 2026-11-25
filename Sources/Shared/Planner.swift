import Foundation
#if canImport(UserNotifications)
import UserNotifications

/// Local prayer-time alerts for today only. The server holds one day at a time, so alerts for later days cannot be planned.
public enum Planner {
    private static let prefix = "prayer."

    public static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    public static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces every pending prayer alert with today's remaining ones for this day's mosque.
    /// Old alerts are always removed, so a changed default mosque or a turned-off switch leaves nothing behind.
    public static func reschedule(for day: PrayerResponse?, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })

        guard let day, TimeLogic.isToday(day, now: now), Store.notifyPrayers || Store.notifySunrise else { return }
        let s = await status()
        guard s == .authorized || s == .provisional else { return }
        guard let zone = TimeZone(identifier: day.mosque.timezone) else { return }

        var jobs: [(String, String, Date)] = []   // title, time text, moment
        if Store.notifyPrayers {
            for item in TimeLogic.schedule(day) where item.at > now {
                jobs.append((item.row.prayer.title, item.row.main ?? "", item.at))
            }
        }
        if Store.notifySunrise, let t = day.beginning.sunrise, let at = TimeLogic.instant(t, on: day.date, zone: zone), at > now {
            jobs.append(("Sunrise", t, at))
        }
        for (title, time, at) in jobs {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "\(day.mosque.name) \u{00B7} \(time)"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, at.timeIntervalSince(now)), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "\(prefix)\(day.mosque.slug).\(title.lowercased())", content: content, trigger: trigger))
        }
    }
}
#endif
