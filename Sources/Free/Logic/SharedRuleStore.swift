import Foundation

/// Bridge between the main app (writer) and the content-filter extension (reader),
/// backed by the shared App Group container. The app republishes the active
/// allowed-rule set and blocking flag whenever they change; the extension reads
/// them on each flow to decide allow/drop.
///
/// This is the v2 (App Store / Network Extension) blocking path. It does not
/// replace the v1 AppleScript engine — both can coexist.
public enum SharedRuleStore {
    public static let appGroupID = "group.com.benni.Free"

    private enum Key {
        static let isBlocking = "shared.isBlocking"
        static let allowedRules = "shared.allowedRules"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Called by the app whenever blocking state or the active rule set changes.
    public static func publish(isBlocking: Bool, allowedRules: [String]) {
        guard let defaults else { return }
        defaults.set(isBlocking, forKey: Key.isBlocking)
        defaults.set(allowedRules, forKey: Key.allowedRules)
    }

    /// Read by the extension on each flow.
    public static func snapshot() -> (isBlocking: Bool, allowedRules: [String]) {
        guard let defaults else { return (false, []) }
        let rules = defaults.array(forKey: Key.allowedRules) as? [String] ?? []
        return (defaults.bool(forKey: Key.isBlocking), rules)
    }
}
