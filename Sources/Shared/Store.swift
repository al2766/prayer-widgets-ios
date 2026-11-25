import Foundation

/// Settings shared by the app and the widget. Uses the App Group when it exists, so the widget can read what the app saved.
public enum Store {
    public static let group = "group.com.zorell.prayerwidgets"

    public static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    public static var defaultSlug: String? {
        get { defaults.string(forKey: "defaultSlug") }
        set { defaults.set(newValue, forKey: "defaultSlug") }
    }
    public static var themeId: String {
        get { defaults.string(forKey: "themeId") ?? WidgetTheme.all[0].id }
        set { defaults.set(newValue, forKey: "themeId") }
    }
    public static var layoutId: String {
        get { defaults.string(forKey: "layoutId") ?? WidgetLayout.classic.rawValue }
        set { defaults.set(newValue, forKey: "layoutId") }
    }
    public static var notifyPrayers: Bool {
        get { defaults.bool(forKey: "notifyPrayers") }
        set { defaults.set(newValue, forKey: "notifyPrayers") }
    }
    public static var notifySunrise: Bool {
        get { defaults.bool(forKey: "notifySunrise") }
        set { defaults.set(newValue, forKey: "notifySunrise") }
    }
}
