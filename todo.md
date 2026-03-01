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
- [x] focus mode should show active list
- [x] add to login items - macos startup
- [x] unlock base websites like localhost
- [x] lock/unlock new tabs
- [x] fully test code
- [x] add list selection in pomodoro mode - default on selected from allowed lists
- [ ] allow with toggle search engines searches
- [x] add git steps
  - [x] build and tests

### Calendar

- [ ] allow modification on calendar imports
  - [ ] it shouldn't allow delete
  - [ ] it should be allow edit only of allowed list and break/focus

- [ ] rule for calendar imports - if title contain `*study*` or `*work*`
  - [ ] allow personalization on this rule with settings
  - [ ] allow imports to be all focus
  - [ ] allow personal imports rule about title search and focus time
- [ ] cannot delete imported schdule
  - [ ] future impl: allow modification to calendar if flag is toggled
- [ ] delete multiple scheduled day pop alert out

## Bug

- [x] when first schedule it adds multiple days of the weak instead of the selected. When I schedule once more it behave correctly (select only the day selected)
- [x] allowd list keep rotating in the ui, why? during focus mode
- [x] should be closable if not in strict mode
- [ ] should work with selected list on the schedule

## Performance check

- [ ] cpu usage
- [ ] ram usage
