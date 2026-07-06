import Foundation

/// Bridge between the main app (writer) and the content-filter extension (reader),
/// backed by a JSON file in the shared App Group container. The app republishes
/// the active allowed-rule set and blocking flag whenever they change; the
/// extension reads them on each flow to decide allow/drop.
///
/// A file in the group container is used rather than `UserDefaults(suiteName:)`:
/// app-group `UserDefaults` hits a `cfprefsd` bug ("kCFPreferencesAnyUser with a
/// container is only allowed for System Containers"), which makes cross-process
/// reads silently return defaults. File sharing via `containerURL(...)` is the
/// reliable, Apple-recommended path.
///
/// This is the v2 (App Store / Network Extension) blocking path. It does not
/// replace the v1 AppleScript engine — both can coexist.
public enum SharedRuleStore {
    public static let appGroupID = "YVZG5QKT42.group.com.benni.Free"

    private struct State: Codable {
        var isBlocking: Bool
        var allowedRules: [String]
    }

    private static var fileURL: URL {
        // In the app/extension both have the app-group entitlement, so this
        // resolves to the shared container. In unit tests (no entitlement) it
        // falls back to a per-process temp path so round-trips still work.
        let directory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return directory.appendingPathComponent("free-filter-state.json")
    }

    /// Called by the app whenever blocking state or the active rule set changes.
    public static func publish(isBlocking: Bool, allowedRules: [String]) {
        let state = State(isBlocking: isBlocking, allowedRules: allowedRules)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Read by the extension on each flow.
    public static func snapshot() -> (isBlocking: Bool, allowedRules: [String]) {
        guard
            let data = try? Data(contentsOf: fileURL),
            let state = try? JSONDecoder().decode(State.self, from: data)
        else { return (false, []) }
        return (state.isBlocking, state.allowedRules)
    }
}
