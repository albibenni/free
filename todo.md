# TODO

## v2

- [ ] Network Extension rewrite (`NEFilterDataProvider`) — replaces the AppleScript/AX
      blocking engine with a system-wide content filter. Sandbox-compatible, so it
      unlocks Mac App Store distribution, and blocks all browsers/apps with no polling
      window. Requires applying to Apple for the Network Extension entitlement first.
      Context: App Sandbox blocks NSAppleScript events and the Accessibility API, so
      the current engine can never pass App Store review (see Docs/build-and-release.md).

- [ ] Focus stats history (extends the v1 "focused today" header stat) — persist
      per-day focus totals and surface trends: a week/month history view, streaks,
      and daily goals. v1 only tracks the current day (resets at local midnight,
      counts `isBlocking && !isPaused`). The NEFilterDataProvider engine also makes
      the accumulator more accurate (no 1.5s polling window / lost partial minute on
      crash), so revisit the tracking source once that lands.

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
