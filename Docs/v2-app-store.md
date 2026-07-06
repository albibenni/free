# v2 — App Store build (Network Extension)

v2 ships Free on the **Mac App Store** using a content-filter system extension
instead of the v1 AppleScript engine. Both builds coexist: v1 remains the
Developer-ID DMG (`build.sh`/`package.sh`), v2 is an Xcode project.

## Why a different engine

The App Store requires the App Sandbox, which blocks `NSAppleScript` events to
browsers and the Accessibility API — the entire v1 blocking mechanism. A
`NEFilterDataProvider` content filter is sandbox-compatible, needs no per-browser
scripting, has no polling window, and blocks system-wide.

## Structure

| Path | Role |
|---|---|
| `project.yml` | XcodeGen definition (source of truth; `.xcodeproj` is generated + gitignored) |
| `Sources/FreeAppStore/` | v2 app target — reuses `FreeLogic` UI/state; `FilterController` manages the filter |
| `Sources/ContentFilter/` | `NEFilterDataProvider` system extension + its Info.plist |
| `Sources/Free/Logic/SharedRuleStore.swift` | App-Group bridge: app writes rules, extension reads them |
| `Support/*.entitlements` | Sandbox + Network Extension + App Group for each target |

`RuleMatcher`, `RuleSet`, schedules, pomodoro, calendar import, and the AppKit UI
are all reused from the `FreeLogic` SPM package — only the enforcement path changes.

Identifiers: app `com.benni.Free`, extension `com.benni.Free.ContentFilter`,
App Group `group.com.benni.Free`, team `YVZG5QKT42`.

## Prerequisites (do these first — the entitlement is gated by Apple)

1. **Request the Network Extension entitlement** on the developer portal
   (`com.apple.developer.networking.networkextension` → content-filter-provider).
   Apple must approve it; this can take days, so start it before building.
2. **Register the App Group** `group.com.benni.Free` in the portal and enable it
   on both the app and extension App IDs.
3. `brew install xcodegen`, then `xcodegen generate` to produce `Free.xcodeproj`.

## Build

```bash
xcodegen generate      # re-run after adding/removing files (it snapshots the tree)
open Free.xcodeproj    # set signing team, then Run
# compile check without signing:
xcodebuild build -project Free.xcodeproj -scheme Free -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

`FreeLogic` is exposed as a library product in `Package.swift` so both Xcode
targets can link it. The extension is a **system extension** (`SYSX`), entry point
in `Sources/ContentFilter/main.swift` (`NEProvider.startSystemExtensionMode()`),
principal class declared under `NetworkExtension → NEProviderClasses` in its
Info.plist. On macOS the filter sees `NEFilterSocketFlow`s (no browser flows);
hostname comes from `flow.url` or the socket's `remoteFlowEndpoint`.

Gotcha: re-run `xcodegen generate` whenever you add files under `Sources/ContentFilter`
or `Sources/FreeAppStore` — the generated `.xcodeproj` won't see them otherwise.

## Remaining implementation work

Tracked in `todo.md` (v2 section). The scaffold compiles the shared logic; the
wiring still to do:

- Call `FilterController.enable()` when a focus session starts; `disable()` on stop.
- Call `SharedRuleStore.publish(...)` whenever `AppState.isBlocking` or the active
  rule set changes (mirror of the v1 monitor snapshot).
- Verdict refinement in `FilterDataProvider.handleNewFlow` — validate hostname
  extraction for socket vs. browser flows against real traffic once the
  entitlement is approved and the extension can run.
- A block-page UX decision: a dropped flow shows a browser connection error, not
  the v1 styled localhost page — surface "blocked" in-app or via notification.
- App Store Connect record, App-Store provisioning profiles, and a separate
  submission flow (distinct from v1 notarization).
