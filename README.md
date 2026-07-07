# Free

Free is a native macOS focus blocker with strict allowlist enforcement.

## Features

Each feature has a walkthrough in [Docs/full-app.md](Docs/full-app.md) (section 6); deeper references are linked per feature.

- **Focus blocking** with multiple allowed website lists — a 1.5 s browser monitor redirects disallowed tabs to a local block page ([blocking loop](Docs/full-app.md#5-the-blocking-loop-core-logic), [diagram](Docs/diagrams.md#2-blocking-loop-flowchart)).
- **Allowed websites & rule sets** — open-tab import and wildcard URL matching ([walkthrough](Docs/full-app.md#6-6-allowed-websites-and-rule-sets), [URL matching diagram](Docs/diagrams.md#7-url-matching-flow)).
- **Weekly schedules** — full-page calendar default (list toggle) with drag/resize editing; sessions start/stop on wall-clock boundaries ([walkthrough](Docs/full-app.md#6-2-scheduled-focus-blocks), [evaluation diagram](Docs/diagrams.md#5-schedule-evaluation-flow)).
- **Pomodoro and quick breaks** — focus/break cycles with a grace-period lock ([walkthrough](Docs/full-app.md#6-3-pomodoro-timer), [state machine](Docs/diagrams.md#4-pomodoro-state-machine)).
- **Strict mode** — challenge-phrase-protected sessions with quit prevention and tamper repair ([Docs/strict-mode.md](Docs/strict-mode.md)).
- **Calendar import** — EventKit events become focus/break blocks via title rules ([walkthrough](Docs/full-app.md#6-7-calendar-integration), [flow diagram](Docs/diagrams.md#6-calendar-integration-flow)).
- **Daily focus total** — the Focus header shows how long you've focused today (active blocking, breaks excluded), resetting at local midnight.
- **DMG install flow** with optional move to `/Applications`, signing, and notarization ([Docs/build-and-release.md](Docs/build-and-release.md)).

## Tech

- Swift 6 language mode (app and tests) + AppKit, `@Observable` state.
- Accessibility + AppleScript browser automation (`BrowserMonitor` actor).
- EventKit via `CalendarProvider`.
- Local loopback block page via `LocalServer`.

## Documentation

| Doc | What it covers |
|---|---|
| [Docs/full-app.md](Docs/full-app.md) | Deep dive: architecture, modules, threading, blocking loop, every feature, persistence, testing |
| [Docs/diagrams.md](Docs/diagrams.md) | Mermaid diagrams for the main flows |
| [Docs/architecture-patterns.md](Docs/architecture-patterns.md) | Debouncer vs event-driven: when this codebase uses each |
| [Docs/strict-mode.md](Docs/strict-mode.md) | Strict mode behavior, tamper resistance, and honest limits |
| [Docs/build-and-release.md](Docs/build-and-release.md) | Build paths, signing/notarization, tests and coverage gates, git hooks, CI, Homebrew tap |

## Commands

```bash
./build.sh          # debug Free.app
./package.sh        # signed release DMG (see Docs/build-and-release.md)
swift test          # full suite
swift run FreeApp   # run via SwiftPM
make coverage       # coverage report (gates: make coverage-gates)
make hooks          # install git hooks (pre-commit runs scripts/validate.sh)
```

## Getting Started

1. Build and run:

```bash
./build.sh
open Free.app
```

2. On first launch, grant:
   - Accessibility + Automation (for browser control)
   - Calendar access (only if you use calendar import)

## UI Overview

- Schedules is a main app section (not a separate dialog).
- Schedules opens in full-page calendar view by default, with a list view toggle.

## Requirements

- macOS 26+ (Apple Silicon)
- Accessibility and Automation permissions for browser control
