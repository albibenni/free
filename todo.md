# TODO

## v2 — App Store (Network Extension)

Scaffold landed (project.yml, Sources/ContentFilter, Sources/FreeAppStore,
SharedRuleStore, Support/*.entitlements). See Docs/v2-app-store.md. Remaining:

- [ ] Request Network Extension entitlement (content-filter-provider) on the portal — gated by Apple, start first
- [ ] Register App Group `group.com.benni.Free` on both App IDs
- [ ] `brew install xcodegen && xcodegen generate`, resolve any target/build settings
- [x] Publish blocking flag + allowed rules to shared App Group (AppState.publishSharedFilterState, called from reassertPersistedSessionFlags)
- [x] Enable the filter at launch (FreeAppStore/main.swift) — installs/activates the system extension
- [ ] Move filter enable/disable behind a Settings toggle (currently auto-enables at launch)
- [ ] Disable the v1 AppleScript BrowserMonitor in the v2 app (avoids benign sandboxed AppleScript permission errors)
- [ ] Validate hostname extraction + verdicts in `FilterDataProvider.handleNewFlow` against real traffic (needs the running signed extension)
- [ ] Block-page UX (dropped flow = browser error, not the v1 localhost page)
- [ ] App Store Connect record + App Store provisioning + submission flow

## UI

### TOPBAR

## Logic

### Allowed list

### Schedule

- [x] change view - calendar view deafult from the tab and toggle to move the list view. Keep both full size, not in a separate dialog

- [ ] imported title make it more visible on edit view

## Bug

- [x] break schedule active and pomodoro active - schedule takes over

## Strict mode

- [x] on wrong writing raise an alert signaling it

## Misc
