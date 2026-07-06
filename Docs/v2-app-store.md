# v2 — App Store build (Network Extension)

v2 ships Free on the **Mac App Store** using a content-filter app extension
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
| `Sources/ContentFilter/` | `NEFilterDataProvider` app extension (.appex) + its Info.plist |
| `Sources/Free/Logic/SharedRuleStore.swift` | App-Group bridge: app writes rules, extension reads them |
| `Support/*.entitlements` | Sandbox + Network Extension + App Group for each target |

`RuleMatcher`, `RuleSet`, schedules, pomodoro, calendar import, and the AppKit UI
are all reused from the `FreeLogic` SPM package — only the enforcement path changes.

Identifiers: app `com.benni.Free`, extension `com.benni.Free.ContentFilter`,
App Group `YVZG5QKT42.group.com.benni.Free`, team `YVZG5QKT42`.

## Prerequisites (do these first — the entitlement is gated by Apple)

1. **Request the Network Extension entitlement** on the developer portal
   (`com.apple.developer.networking.networkextension` → content-filter-provider).
   Apple must approve it; this can take days, so start it before building.
2. **Register the App Group** in the portal as `group.com.benni.Free` and enable it on
   both App IDs. **On macOS the entitlement/container form is Team-ID-prefixed** —
   `YVZG5QKT42.group.com.benni.Free` — which is what the entitlements and
   `SharedRuleStore.appGroupID` use (the automatic profile grants `YVZG5QKT42.*`).
3. `brew install xcodegen`, then `xcodegen generate` to produce `Free.xcodeproj`.

## Build

```bash
xcodegen generate      # re-run after adding/removing files (it snapshots the tree)
open Free.xcodeproj    # set signing team, then Run
# compile check without signing:
xcodebuild build -project Free.xcodeproj -scheme Free -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

`FreeLogic` is exposed as a library product in `Package.swift` so both Xcode
targets can link it. The extension is an **app extension** (`.appex`, `NSExtensionPointIdentifier`
`com.apple.networkextension.filter-data`, principal class `FilterDataProvider`).
`NEFilterManager` loads it directly — no `OSSystemExtensionRequest`, no
`/Applications` requirement, so it runs from Xcode. App extensions are
App-Store-only, which is exactly v2's channel (v1 covers direct distribution).

On macOS the filter sees `NEFilterSocketFlow`s (no browser flows); hostname comes
from `flow.url` or the socket's `remoteFlowEndpoint`.

### Gotchas (all hit and fixed during bring-up)

- **Re-run `xcodegen generate`** whenever you add files under `Sources/ContentFilter`
  or `Sources/FreeAppStore` — the generated `.xcodeproj` snapshots the tree.
- **App groups are Team-ID-prefixed on macOS** (`YVZG5QKT42.group.…`), not the iOS
  `group.…` form. A mismatch makes App Sandbox init `SIGTRAP` before `main`.
- **Custom `INFOPLIST_FILE`s must include `CFBundleIdentifier`** (and the other
  standard `CFBundle*` keys, referencing build settings like
  `$(PRODUCT_BUNDLE_IDENTIFIER)`). Xcode only auto-injects these when it generates
  the Info.plist; with a hand-written one, a missing bundle id makes `secinitd`
  fail to create the sandbox container → launch `SIGTRAP` in `_libsecinit_appsandbox`.
- Diagnosing a launch `SIGTRAP`: `log show --last 30s --predicate 'process == "secinitd"'`
  surfaces the real reason (e.g. "Info.plist … has no value for kCFBundleIdentifierKey").

## Remaining implementation work

Tracked in `todo.md` (v2 section). Done: the app builds/runs from Xcode, publishes
rules to the shared store on state change, and enables the filter on first session
start. Still to do:

- Verdict refinement in `FilterDataProvider.handleNewFlow` — validate hostname
  extraction against real socket flows now that the extension can run from Xcode.
- A block-page UX decision: a dropped flow shows a browser connection error, not
  the v1 styled localhost page — surface "blocked" in-app or via notification.
- App Store Connect record, App-Store provisioning profiles, and a separate
  submission flow (distinct from v1 notarization).
