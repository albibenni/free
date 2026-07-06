# TODO

## v2 — App Store (Network Extension)

Full scaffold + build/sign/notarize pipeline done. See Docs/v2-app-store.md.

DONE:
- [x] System-extension packaging (project.yml `system-extension`, Sources/ContentFilter, main.swift, SYSX Info.plist w/ NEProviderClasses)
- [x] Portal: App IDs (com.benni.Free, com.benni.Free.ContentFilter) + App Group + Developer ID provisioning profiles (Free DevID / Free CF DevID)
- [x] Correct entitlement: `content-filter-provider-systemextension` (NOT the plain app-extension variant)
- [x] App Group file bridge SharedRuleStore (file in container, not UserDefaults — cfprefsd bug); AppState publishes blocking flag + rules
- [x] Manual Developer-ID signing + Hardened Runtime; scripts/package-v2.sh archives → exports → notarizes → installs (notarization Accepted, Gatekeeper accepted)
- [x] App unsandboxed (Developer-ID sysext host must be); extension stays sandboxed

BLOCKED — system extension won't activate:
- OSSystemExtensionRequest returns "Extension not found in App bundle" for a build that is correct by every check (notarized, right identifier/entitlement, in /Applications, single LS registration, SIP off, dev mode on, DB reset). Xcode ⌘R also fails.
- [ ] NEXT: build Apple's "Filtering Network Traffic" NEFilterDataProvider sample and try to activate it. Fails too → machine/OS state; works → diff its project against ours to find the delta.

AFTER ACTIVATION WORKS:
- [ ] Validate hostname extraction + verdicts in FilterDataProvider.handleNewFlow vs real traffic (per-flow logging already added; watch for IP/QUIC flows with no hostname)
- [ ] Block-page UX (dropped flow = browser connection error, not the v1 localhost page)
- [ ] Hide v1-only UI in v2 (Accessibility banner, Import Open Tabs — both meaningless under sandbox/content-filter)
- [ ] Move filter enable/disable behind a Settings toggle (currently auto-enables at launch)
- [ ] App Store path: re-add App Sandbox to the app, switch to App Store provisioning + Apple Distribution cert, App Store Connect record, TestFlight

NOTE: project is currently in Developer-ID test config (manual signing, app unsandboxed). Machine is at reduced security + SIP disabled for testing — re-enable SIP (`csrutil enable`) when done.

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
