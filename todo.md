## UI

- [x] personalize accent color
- [x] caldendar schedule can personalize color
- [] light mode:
  - [ ] background color not white

### TOPBAR

- [ ] add infos
  - [ ] add calendar schedule, next one
  - [ ] add active list
  - [ ] add if unbreakable mode is on

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
- [x] focus mode should show active list
- [x] add to login items - macos startup
- [x] unlock base websites like localhost
- [x] lock/unlock new tabs
- [x] fully test code
- [x] add list selection in pomodoro mode - default on selected from allowed lists
- [ ] allow with toggle search engines searches
- [x] add git steps
  - [x] build and tests

### Allowed list

- [x] allow multiple selection to delete
- [x] check current open websites
  - [x] add button to add for each listed website of the open
- [x] create new list

### Calendar

- [x] allow modification on calendar imports
  - [x] it shouldn't allow delete
  - [x] it should be allow edit only of allowed list and break/focus
  - [x] multiple scheduled at the same time
    - [x] UI
    - [x] logic
      - [x] who manage the list
      - [x] who manage break or focus
      - [x] if the other is longer keep it in memory after end

- [ ] rule for calendar imports - if title contain `*study*` or `*work*`
  - [ ] allow personalization on this rule with settings
  - [ ] allow imports to be all focus
  - [ ] allow personal imports rule about title search and focus time
- [ ] cannot delete imported schdule
  - [ ] future impl: allow modification to calendar if flag is toggled
- [ ] delete multiple scheduled day pop alert out
- [ ] define in setting which allowed list should be used for imported schedule

## Bug

- [x] when first schedule it adds multiple days of the weak instead of the selected. When I schedule once more it behave correctly (select only the day selected)
- [x] allowd list keep rotating in the ui, why? during focus mode
- [x] should be closable if not in strict mode
- [x] should work with selected list on the schedule
- [x] change to break doesn't work for imported schedules
- [ ] ci-cd running weird - on wrong branch
- [ ] merge allowed on ci-cd failed
- [ ] ci-cd fix tests failing

### Regression appkit

- [x] app state change not highlighting correctly and lag
  - [x] state change should follow color schema
- [x] can't close cmd+q the app
- [x] buttons don't follow color schema - matte instead of shaded
- [x] app icons without padding - side bar
- [x] light mode not working - background is black with black text
- [x] color schema for the app
  - [x] toggle buttons
  - [x] focus highlight
- [x] calendar view redraw
- [x] Allowed list
  - [x] add impossible to use
  - [x] current website open not working
  - [x] close tab button small
  - [x] FreeAppKitShell too big, refactor
  - [x] new floating window don't follow tab 'connection'

- [ ] redo tests
  - [ ] coverage

## Performance check

- [ ] cpu usage
- [ ] ram usage

## TODO: pass

Highest-impact findings

Duplicate UI architecture is still present and overlapping.
FreeFeatureViewControllers.swift (line 76), FreeFeatureWidgets.swift (line 236), FreeMainViewController.swift (line 1), AllowedWebsitesFloatingEditorViewController.swift (line 58)
This causes drift/regressions because similar behaviors live in multiple places.

AppState is a God object (state + persistence + schedule engine + pomodoro + calendar merge + timer lifecycle).
AppState.swift (line 10)
It should be split into domain services (ScheduleEngine, PomodoroEngine, RuleSetService, CalendarImportService, SettingsStore).

SchedulesView.swift bundles too many responsibilities in one file (controller + nested views + custom drawing).
SchedulesView.swift (line 4), SchedulesView.swift (line 461), SchedulesView.swift (line 827)
Split into SchedulesToolbarView, SchedulesListView, SchedulesListRowView, SchedulesCoordinator.

AppKitUIHelpers.swift is effectively a framework in one file.
AppKitUIHelpers.swift (line 24), AppKitUIHelpers.swift (line 332), AppKitUIHelpers.swift (line 916)
Split by component type (Buttons, Cards, SelectionControls, SymbolHelpers, ColorHelpers).

Allowed Websites floating editor still mixes layout, styling, list management, table datasource, and import flow in one class.
AllowedWebsitesFloatingEditorViewController.swift (line 104), AllowedWebsitesFloatingEditorViewController.swift (line 558)
Also, multi-select restore currently preserves only one row.
AllowedWebsitesFloatingEditorViewController.swift (line 474)

Symbol rendering still has duplicate helpers in some UI surfaces.
WeeklyCalendarSurface.swift (line 943)
This should use shared symbol helpers/specs only.

Suggested refactor order

Remove/retire duplicated legacy UI path (FreeFeature*) and keep one AppKit surface.
Split AppState into domain services with thin orchestration.
Split SchedulesView.swift into focused view/controller components.
Split AppKitUIHelpers.swift into smaller files by concern.
Split Allowed Websites editor into View, Controller, ImportCoordinator.
Finish symbol-helper unification (WeeklyCalendarSurface).
If you want, I can start implementing this in that order and keep each step as small, testable PR-style chunks.
