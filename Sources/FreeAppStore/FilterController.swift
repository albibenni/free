import NetworkExtension
import FreeLogic
import os

/// v2 app-side controller for the content-filter system extension: enables it
/// (triggering the system permission prompt) and republishes the active rules
/// into the shared App Group whenever blocking state changes.
@MainActor
final class FilterController {
    private let log = Logger(subsystem: "com.benni.Free", category: "filter-controller")

    /// Enable the content filter, prompting the user for permission the first time.
    func enable() async throws {
        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()

        if manager.providerConfiguration == nil {
            let config = NEFilterProviderConfiguration()
            // macOS filters socket flows only; filterBrowsers is iOS-only.
            config.filterSockets = true
            manager.providerConfiguration = config
            manager.localizedDescription = "Free"
        }
        manager.isEnabled = true
        try await manager.saveToPreferences()
        log.info("Content filter enabled")
    }

    func disable() async throws {
        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()
        manager.isEnabled = false
        try await manager.saveToPreferences()
    }

    /// Push the current blocking state + allowed rules to the extension.
    func publish(isBlocking: Bool, allowedRules: [String]) {
        SharedRuleStore.publish(isBlocking: isBlocking, allowedRules: allowedRules)
    }
}
