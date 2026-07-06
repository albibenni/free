# TODO

## v2

- [ ] Network Extension rewrite (`NEFilterDataProvider`) — replaces the AppleScript/AX
      blocking engine with a system-wide content filter. Sandbox-compatible, so it
      unlocks Mac App Store distribution, and blocks all browsers/apps with no polling
      window. Requires applying to Apple for the Network Extension entitlement first.
      Context: App Sandbox blocks NSAppleScript events and the Accessibility API, so
      the current engine can never pass App Store review (see Docs/build-and-release.md).

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
