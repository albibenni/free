## UI

- [x] personalize accent color
- [x] caldendar schedule can personalize color

## Logic

- [x] there should be a setting, maybe a setting tab where you can enable an UNBLOCKABLE feature where you cannot toggle the focus button
- [x] the app should manage focus mode via calendar schedule, like a google calendar app
- [x] fix drag - should round to 15m
  - [x] overlay showing time selected?
- [x] integrate with google calendar?
- [x] modes for focus:
  - [x] pomodoro:
  - [x] personalize timer: eg 50m focus on 15m off
  - [x] setting to disable calendar, if strict is off
  - [x] free time disable focus even with calendar enabled
- [x] the take a break shouldn't be allowed if it's strict mode, either pomodoro or focus
  - [x] with a break it should pause the pomodoro - then restart it
- [x] list can add websites from open list?
  - [x] remove list selection from general ui
  - [x] focus session should default to the first list - not none
- [x] add default pomodoro timer - most used ones
- [ ] focus mode should show active list

## Bug

- [x] when first schedule it adds multiple days of the weak instead of the selected. When I schedule once more it behave correctly (select only the day selected)
- [x] allowd list keep rotating in the ui, why? during focus mode

## Possible issues:

[P1] Allowlist bypass via substring matching in internal-scheme checks
RuleMatcher.swift (line 8) and RuleMatcher.swift (line 10) use cleanedUrl.contains(...). Any blocked URL containing about:, arc:, or localhost (line 10000) in query/path can be treated as allowed.

[P1] Overnight schedule weekday logic is incorrect
Schedule.swift (line 49) checks only the current weekday before overnight logic at Schedule.swift (line 64). A Monday 22 (lines 0-2, column 0) session can wrongly match Monday 01:00 and miss Tuesday 01:00.
The test currently reinforces this behavior: ScheduleTests.swift (line 76).

[P2] Core enforcement path is weakly tested
BrowserMonitor is the critical blocker path, but line coverage is low (16.8%) and the test explicitly avoids real enforcement flow: BrowserMonitorTests.swift (line 42). This leaves redirect decisions and frontmost-app integration under-tested.

[P2] Deprecated Process API in production code
AppDelegate.swift (line 48) and AppDelegate.swift (line 50) use launchPath/launch(). For modern macOS Swift, use executableURL + run().

[P2] Timer lifecycle/thread-safety risk
Repeating timers are created in AppState.swift (line 141), AppState.swift (line 255), AppState.swift (line 269), BrowserMonitor.swift (line 35), CalendarManager.swift (line 26) without teardown hooks (deinit). This can leave background polling active and complicate correctness.

[P2] Clean-architecture boundary leak
Model logic depends on UI type: Schedule.swift (line 91) calls WeeklyCalendarView.getWeekDates. This is a coupling smell against clean code boundaries.
