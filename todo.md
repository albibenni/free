# TODO

## UI

- [x] personalize accent color
- [x] caldendar schedule can personalize color
- [] light mode:
  - [ ] background color not white
- [ ] better ui tbd
  - [x] try smoky ui
- [x] gray on smoke become purple
- [x] reduce animation size - SPLAT_RADIUS
- [x] a bit of opacity on the animation
- [x] toggle disable animation

- [ ] settings:
  - [ ] "Strict mode is active" in settings should be under the Browser blocking section
  - [ ] the toggle allow under Browser should all be "Allow..." instead of some "Allow..." and some "Block..."

### TOPBAR

- [ ] add infos
  - [x] add calendar schedule, next one
  - [x] add active list
  - [x] add if unbreakable mode is on
  - [x] pomodoro timer - break or focus what's left
- [x] open app

## Logic

- [x] there should be a setting, maybe a setting tab where you can enable an STRICT feature where you cannot toggle the focus button
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
- [x] with strict mode on schedule cannot be modified

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

## Strict mode

- [x] regression:
  - [x] can modify schedule with strict mode on
    - [x] dialog should show new quote and new challenge phrase

- [x] quick break cannot be pressed in strict mode
  - [x] should be a dialog challenge to start the break if strict mode is on

- [x] pomodoro stop button cannot be pressed in strict mode
  - [x] should be a dialog challenge to stop the pomodoro if strict mode is on
- [x] dialog vanished from add websites inside import open tabs
- [ ] dialog - challenge for blocked toggle if strict mode is on
- [x] dialog - challeng in schedule it pop up but on click, then the save button is blocked
  - [x] remove edit schedule dialog
  - [x] add dialog challenge when creating a schedule with strict mode on or clicking save on a schedule with strict mode on
  - [x] delete schedule work as intended
- [x] toggle in settings disabled by strict mode should work with the dialog challenge
- [x] don't allow to copy paste the challenge phrase
  - [x] still allows right click copy paste - should be disabled
  - [x] remove the text selection on the dialog
- [x] on import open tabs - if strict mode is on the dialog should pop up once the website are selected and clicking the add button should trigger the dialog challenge
- [x] schedule if strict mode is on should not open the dialog challenge when you click on the schedule, but only when you click on save after modifying it or creating a new one
- [x] calendar tab strict mode
  - [x] the add rules (like *work* or *study*) should trigger the dialog challenge if strict mode is on
  - [x] the delete of imported schedule should trigger the dialog challenge if strict mode is on

- [x] quick break in strict mode should be clickable but trigger the dialog challenge, if accepted start the break, if not do nothing
- [x] pomodoro stop in strict mode should be clickable but trigger the dialog challenge, if accepted stop the pomodoro, if not do nothing
- [x] replace old strict-mode messages with just "Strict mode is active" everywhere in the app

## Performance check

- [x] auto remove previous calendar imports - if they are in the past week
- [x] cpu usage
- [x] ram usage

## Future features

- [ ] calendar should be calendar settings at the bottom - tab
- [ ] block apps
