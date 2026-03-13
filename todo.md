## UI

- [x] personalize accent color
- [x] caldendar schedule can personalize color
- [] light mode:
  - [ ] background color not white
- [ ] better ui tbd

### TOPBAR

- [ ] add infos
  - [x] add calendar schedule, next one
  - [x] add active list
  - [x] add if unbreakable mode is on
  - [x] pomodoro timer - break or focus what's left
- [x] open app

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
- [x] allow with toggle search engines searches
- [x] add git steps
  - [x] build and tests
- [x] breaks allowed or not base on settings toggle
  - [x] breaks only in first view - mode there from pomodoro
  - [x] pomodoro setting for it
  - [x] calendar setting for it
- [x] with unblockable mode on schedule cannot be modified

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

- [x] rule for calendar imports - if title contain `*study*` or `*work*`
  - [x] allow personalization on this rule with settings
  - [x] allow imports to be all focus
  - [x] allow personal imports rule about title search and focus time
- [x] cannot delete imported schdule
  - [x] future impl: allow modification to calendar if flag is toggled
- [x] delete multiple scheduled day pop alert out
- [x] define in setting which allowed list should be used for imported schedule

## Bug

- [x] when first schedule it adds multiple days of the weak instead of the selected. When I schedule once more it behave correctly (select only the day selected)
- [x] allowd list keep rotating in the ui, why? during focus mode
- [x] should be closable if not in strict mode
- [x] should work with selected list on the schedule
- [x] change to break doesn't work for imported schedules
- [x] ci-cd running weird - on wrong branch
- [x] merge allowed on ci-cd failed
- [x] ci-cd fix tests failing

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
- [x] pomodoro timer can be changed during focus via preset click, it shouldn't be possible
- [x] end break and focus button don't work - the one in pomodoro widget

- [x] redo tests
  - [x] coverage

## Performance check

- [x] auto remove previous calendar imports - if they are in the past week
- [ ] cpu usage
- [ ] ram usage

## Simplify issues

- [ ] any in LaunchAtLoginService.swift

## Future features

- [ ] block apps
