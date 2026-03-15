# Free

Free is a native macOS focus blocker with strict allowlist enforcement.

## Features
- Focus blocking with multiple allowed website lists.
- Open-tab import and wildcard URL matching.
- Weekly schedules (calendar + list) with drag/resize editing.
- Pomodoro (focus/break), quick breaks, and strict unblockable mode.
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

## Requirements
- macOS 14+
- Accessibility and Automation permissions for browser control
