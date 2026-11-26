import Foundation

/// Settings shared by the app and the widget. Uses the App Group when it exists, so the widget can read what the app saved.
public enum Store {
    public static let group = "group.com.zorell.prayerwidgets"

    public static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    public static var defaultSlug: String? {
        get { defaults.string(forKey: "defaultSlug") }
        set { defaults.set(newValue, forKey: "defaultSlug") }
    }

    // Theme and layout are chosen per widget size (small, medium). Every widget of that size follows them.
    public static func themeId(_ size: WidgetSize) -> String {
        defaults.string(forKey: "themeId.\(size.rawValue)") ?? defaults.string(forKey: "themeId") ?? WidgetTheme.all[0].id
    }
    public static func setThemeId(_ id: String, for size: WidgetSize) { defaults.set(id, forKey: "themeId.\(size.rawValue)") }

    public static func layoutId(_ size: WidgetSize) -> String {
        defaults.string(forKey: "layoutId.\(size.rawValue)") ?? (size == .small ? WidgetLayout.nextFocus.rawValue : WidgetLayout.classic.rawValue)
    }
    public static func setLayoutId(_ id: String, for size: WidgetSize) { defaults.set(id, forKey: "layoutId.\(size.rawValue)") }

    public static var notifyPrayers: Bool {
        get { defaults.bool(forKey: "notifyPrayers") }
        set { defaults.set(newValue, forKey: "notifyPrayers") }
    }
    public static var notifySunrise: Bool {
        get { defaults.bool(forKey: "notifySunrise") }
        set { defaults.set(newValue, forKey: "notifySunrise") }
    }

    /// The city the user chose for the Qibla direction. nil means "use my device's location".
    public static var place: Place? {
        get { defaults.data(forKey: "place").flatMap { try? JSONDecoder().decode(Place.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "place") }
    }

    /// Masjid requests this phone has made. There are no accounts, so the phone keeps its own list.
    public static var requests: [SavedRequest] {
        get { defaults.data(forKey: "requests").flatMap { try? JSONDecoder().decode([SavedRequest].self, from: $0) } ?? [] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "requests") }
    }
}
