# Free

Free is a native macOS focus blocker with strict allowlist enforcement.

## Features

- Focus blocking with multiple allowed website lists.
- Open-tab import and wildcard URL matching.
- Weekly schedules with full-page calendar default (list toggle) and drag/resize editing.
- Pomodoro (focus/break), quick breaks, and strict mode.
- Calendar import with title-based focus/break rules.
- DMG install flow with optional move to `/Applications`.

## Tech

- Swift 6 + AppKit.
- Accessibility + AppleScript browser automation.
- EventKit via `CalendarProvider`.
- Local block page via `LocalServer`.

## Commands

```bash
./build.sh
./package.sh
swift test
make coverage
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

- macOS 26+
- Accessibility and Automation permissions for browser control
