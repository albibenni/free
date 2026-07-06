import Foundation
import FreeLogic

// v2 (App Store) entry point. Reuses the shared UI and state from FreeLogic.
// Blocking is enforced by the ContentFilterExtension system extension: AppState
// publishes the effective blocking flag + allowed rules into the shared App Group
// (AppState.publishSharedFilterState), and the extension reads them per flow.
//
// - startBrowserMonitor: false — the v1 AppleScript engine stays off (the filter
//   replaces it), which also avoids sandboxed Apple Events permission noise.
// - The filter is enabled the first time a focus session starts, so the one-time
//   System Settings approval prompt appears on user intent rather than at launch.
let filterController = FilterController()
var filterEnabled = false

FreeAppEntry.run(
    startBrowserMonitor: false,
    onBlockingChanged: { isBlocking in
        guard isBlocking, !filterEnabled else { return }
        filterEnabled = true
        Task { @MainActor in
            do { try await filterController.enable() }
            catch { NSLog("Free: content filter enable failed: \(error.localizedDescription)") }
        }
    }
)
