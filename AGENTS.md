# AGENTS.md - Free (macOS)

## Architecture
- AppKit-first macOS app (Swift 6).
- Runtime loop monitors frontmost browser state and evaluates blocking rules.
- URL retrieval/enforcement is decoupled through protocols:
  - `BrowserAutomator`: Accessibility + AppleScript browser control.
  - `CalendarProvider`: EventKit abstraction for calendar import.
  - `LocalServer`: serves local block page (`http://localhost:10000`).
- Domain logic is split into AppState services/coordinators (schedules, rules, pomodoro, calendar sync, persistence).

## Enforcement Model
- Block when:
  - focus is active (manual/schedule/calendar-imported focus session), and
  - visited URL is not allowed by the active allowed list.
- Allow/block overrides:
  - break sessions,
  - manual pause,
  - pomodoro break phase.
- Strict mode (`unblockable`) adds challenge-based disable flows and locks selected settings/actions.

## Current Product Surface
- Multiple allowed lists with wildcard URL matching.
- Weekly schedules (calendar + list) with drag/move/resize editing.
- Pomodoro (focus/break), quick breaks, strict stop rules.
- Calendar integration with title-based import rules (focus/break) and schedule mirroring.
- Floating editors/sheets for schedules and allowed websites.
- Theme + accent support, including multicolor mode.

## Dev Commands
```bash
./build.sh
./package.sh
swift test
make coverage
```

## Platform/Permissions
- macOS 14+.
- Accessibility + Automation permissions required for browser URL control.
