import NetworkExtension
import SystemExtensions
import FreeLogic
import os

/// v2 app-side controller for the content-filter **system extension** (macOS
/// requires system extensions for content filters). Two steps:
///   1. Activate/install the system extension via OSSystemExtensionRequest —
///      triggers the one-time System Settings approval and registers the provider.
///   2. Once activated, configure NEFilterManager to enable filtering.
/// Rules flow to the extension via SharedRuleStore (App Group container file).
///
/// Requires the app to run from /Applications and to carry the
/// `com.apple.developer.system-extension.install` entitlement.
@MainActor
final class FilterController: NSObject, OSSystemExtensionRequestDelegate {
    private let log = Logger(subsystem: "com.benni.Free", category: "filter-controller")
    private let extensionIdentifier = "com.benni.Free.ContentFilter"

    /// Activate the system extension; NEFilterManager is enabled once activation
    /// succeeds (see requestDidFinish).
    func enable() {
        log.info("Requesting system extension activation…")
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func disable() async throws {
        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()
        manager.isEnabled = false
        try await manager.saveToPreferences()
    }

    private func enableFilterConfiguration() {
        Task { @MainActor in
            do {
                let manager = NEFilterManager.shared()
                try await manager.loadFromPreferences()
                if manager.providerConfiguration == nil {
                    let config = NEFilterProviderConfiguration()
                    config.filterSockets = true
                    manager.providerConfiguration = config
                    manager.localizedDescription = "Free"
                }
                manager.isEnabled = true
                try await manager.saveToPreferences()
                log.info("Content filter configuration enabled")
            } catch {
                log.error("Enabling filter configuration failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: OSSystemExtensionRequestDelegate

    nonisolated func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    nonisolated func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        Task { @MainActor in
            log.notice("System extension needs approval in System Settings → General → Login Items & Extensions")
        }
    }

    nonisolated func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        Task { @MainActor in
            log.info("System extension activation finished: \(result.rawValue)")
            self.enableFilterConfiguration()
        }
    }

    nonisolated func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        Task { @MainActor in
            log.error("System extension activation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
