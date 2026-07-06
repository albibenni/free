import Foundation
import FreeLogic

// v2 (App Store) entry point. Reuses the shared UI and state from FreeLogic.
// Blocking is enforced by the ContentFilterExtension system extension; AppState
// publishes the effective blocking flag + allowed rules into the shared App Group
// (AppState.publishSharedFilterState), and the extension reads them per flow.
//
// Install/activate the system extension once at launch (prompts for approval the
// first time, and installs it via OSSystemExtensionRequest). This is done at
// launch rather than on session-start because blocking state is persisted: if a
// session is already active at launch, a change-observer would never fire. The
// extension passes all flows through when not blocking, so always-installed is
// harmless. The Task runs after application.run() starts the main run loop.
//
// startBrowserMonitor: false keeps the v1 AppleScript engine off (the filter
// replaces it) and avoids sandboxed Apple Events noise.
//
// TODO: move activation behind a Settings toggle with explanation once the flow
// is validated, so the approval prompt is tied to explicit user intent.
let filterController = FilterController()
Task { @MainActor in
    filterController.enable()
}

FreeAppEntry.run(startBrowserMonitor: false)
