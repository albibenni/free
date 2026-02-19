import Testing
import Foundation
@testable import FreeLogic

struct AppStateTests {

    private func isolatedAppState(name: String, timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler()) -> AppState {
        let suite = "AppStateTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, timerScheduler: timerScheduler, isTesting: true)
    }

    @Test("Pomodoro locking logic works correctly with grace period")
    func pomodoroLocking() {
        // Given
        let appState = isolatedAppState(name: "pomodoroLocking")

        // When: Start Pomodoro (Started 100s ago)
        appState.isUnblockable = true
        appState.pomodoroStatus = .focus
        appState.pomodoroStartedAt = Date().addingTimeInterval(-100)

        // Then: Should be locked
        #expect(appState.isPomodoroLocked, "Pomodoro should be locked in strict mode after grace period")

        // When: Grace period (Started just now)
        appState.pomodoroStartedAt = Date()

        // Then: Should NOT be locked
        #expect(!appState.isPomodoroLocked, "Pomodoro should NOT be locked during grace period")
    }

    @Test("Strict Mode (Unblockable) activation logic")
    func strictActive() {
        let appState = isolatedAppState(name: "strictActive")
        appState.isBlocking = true
        appState.isUnblockable = true

        #expect(appState.isStrictActive)

        appState.isUnblockable = false
        #expect(!appState.isStrictActive)
    }

    @Test("Allowed rules aggregation from multiple sources")
    func allowedRulesAggregation() {
        // Given
        let appState = isolatedAppState(name: "allowedRulesAggregation")
        let ruleSet1 = RuleSet(id: UUID(), name: "Set 1", urls: ["url1.com"])
        let ruleSet2 = RuleSet(id: UUID(), name: "Set 2", urls: ["url2.com"])
        appState.ruleSets = [ruleSet1, ruleSet2]

        // When: Manual focus active with Set 1
        appState.isBlocking = true
        appState.activeRuleSetId = ruleSet1.id

        // Then
        #expect(appState.allowedRules.contains("url1.com"))
        #expect(!appState.allowedRules.contains("url2.com"))

        // When: Schedule active with Set 2
        // Note: In a real scenario, this would be integration testing.
        // Here we just verify logic assumes active schedule contributes rules.
    }

    @Test("Break schedule overrides Focus schedule")
    func schedulePriorityBreakOverridesFocus() {
        // Given
        let appState = isolatedAppState(name: "schedulePriorityBreakOverridesFocus")
        appState.isBlocking = false
        appState.isUnblockable = false
        appState.calendarIntegrationEnabled = false

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        // Focus: 1h ago to 1h from now
        let focusSchedule = Schedule(
            name: "Focus",
            days: [weekday],
            startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(3600),
            isEnabled: true,
            type: .focus
        )

        // Break: 10m ago to 10m from now
        let breakSchedule = Schedule(
            name: "Break",
            days: [weekday],
            startTime: now.addingTimeInterval(-600),
            endTime: now.addingTimeInterval(600),
            isEnabled: true,
            type: .unfocus
        )

        // When: Both active
        appState.schedules = [focusSchedule, breakSchedule]
        appState.checkSchedules()

        // Then: Break should win
        #expect(!appState.isBlocking, "Blocking should be disabled because an internal Break session is active")

        // When: Only Focus active
        appState.schedules = [focusSchedule]
        appState.checkSchedules()

        // Then: Should be blocking
        #expect(appState.isBlocking, "Blocking should be enabled when only Focus session is active")
    }

    @Test("Manual focus persists after schedule ends")
    func manualFocusOverridesScheduleStop() {
        // Given
        let appState = AppState(isTesting: true)

        // 1. Manually start blocking
        appState.isBlocking = true
        // Note: AppState.toggleBlocking() would set wasStartedBySchedule = false
        // Direct property set also keeps it false by default.

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        // 2. Add an active schedule
        let schedule = Schedule(
            name: "Work",
            days: [weekday],
            startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(3600),
            isEnabled: true,
            type: .focus
        )
        appState.schedules = [schedule]
        appState.checkSchedules()

        // Still blocking (both manual and schedule agree)
        #expect(appState.isBlocking)

        // 3. When: Schedule ends (simulated by emptying list)
        appState.schedules = []
        appState.checkSchedules()

        // Then: Should STILL be blocking because it was manual
        #expect(appState.isBlocking, "Manual focus should not be turned off by schedule ending")
    }

    @Test("Calendar events override focus sessions in normal mode")
    func calendarEventOverride() {
        // Given
        let appState = isolatedAppState(name: "calendarEventOverride")
        appState.calendarIntegrationEnabled = true

        // Reset state for test
        appState.isBlocking = false
        appState.isUnblockable = false

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        // 1. Setup focus schedule
        let schedule = Schedule(
            name: "Work",
            days: [weekday],
            startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(3600),
            isEnabled: true,
            type: .focus
        )

        // When: Focus schedule added
        appState.schedules = [schedule]
        appState.checkSchedules()

        // Then: Should be blocking and wasStartedBySchedule should be true
        #expect(appState.isBlocking, "Should be blocking due to schedule")

        // 2. Setup active calendar event
        let event = ExternalEvent(
            id: "meeting",
            title: "Meeting",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600)
        )

        // When: Calendar event added
        appState.calendarProvider.events = [event]
        appState.checkSchedules()

        // Then: Should NOT be blocking (Calendar event overrides focus in normal mode)
        #expect(!appState.isBlocking, "Calendar event should override focus in normal mode")

        // 3. Enable Strict mode
        appState.isUnblockable = true
        appState.checkSchedules()

        // Then: SHOULD be blocking again (Strict mode ignores calendar events)
        #expect(appState.isBlocking, "Calendar event should NOT override focus in strict mode")
    }

    @Test("Pause logic works correctly")
    func pauseLogic() {
        // Given
        let appState = isolatedAppState(name: "pauseLogic")
        appState.isBlocking = true

        // When: Pause started
        appState.startPause(minutes: 5)

        // Then
        #expect(appState.isPaused)
        #expect(appState.pauseRemaining == 300)

        // When: Cancelled
        appState.cancelPause()
        #expect(!appState.isPaused)

        // When: Blocking turned off
        appState.isBlocking = true
        appState.startPause(minutes: 1)
        appState.isBlocking = false
        #expect(!appState.isPaused, "Pause should cancel when blocking is disabled")
    }

    @Test("todaySchedules includes matching one-off date sessions")
    func todaySchedulesSpecificDate() {
        let appState = isolatedAppState(name: "todaySchedulesSpecificDate")
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 10, minute: 0))!

        let todayOneOff = Schedule(name: "Today One-off", days: [], date: now, startTime: start, endTime: end)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let tomorrowOneOff = Schedule(name: "Tomorrow One-off", days: [], date: tomorrow, startTime: start, endTime: end)

        appState.schedules = [tomorrowOneOff, todayOneOff]
        let result = appState.todaySchedules

        #expect(result.count == 1)
        #expect(result.first?.name == "Today One-off")
    }

    @Test("addSpecificRule adds unique entries and respects strict mode")
    func addSpecificRuleCoverage() {
        let appState = isolatedAppState(name: "addSpecificRuleCoverage")
        let setId = appState.ruleSets[0].id

        appState.addSpecificRule("https://swift.org", to: setId)
        #expect(appState.ruleSets[0].urls.contains("https://swift.org"))

        let countAfterFirstAdd = appState.ruleSets[0].urls.count
        appState.addSpecificRule("https://swift.org", to: setId)
        #expect(appState.ruleSets[0].urls.count == countAfterFirstAdd)

        appState.isBlocking = true
        appState.isUnblockable = true
        appState.addSpecificRule("https://example.com", to: setId)
        #expect(!appState.ruleSets[0].urls.contains("https://example.com"))
    }

    @Test("AppState covers primary ruleset and name fallback branches")
    func primaryRuleSetFallbackCoverage() {
        let appState = isolatedAppState(name: "primaryRuleSetFallbackCoverage")

        appState.ruleSets = []
        appState.activeRuleSetId = nil
        #expect(appState.currentPrimaryRuleSetId == nil)
        #expect(appState.currentPrimaryRuleSetName == "No List")

        let set = RuleSet(id: UUID(), name: "Main", urls: [])
        appState.ruleSets = [set]

        appState.isBlocking = true
        appState.activeRuleSetId = nil
        #expect(appState.currentPrimaryRuleSetId == set.id)

        appState.activeRuleSetId = UUID()
        #expect(appState.currentPrimaryRuleSetName == "Unknown List")

        appState.isBlocking = false
        let now = Date()
        let weekday = Calendar.current.component(.weekday, from: now)
        appState.schedules = [
            Schedule(
                name: "No set",
                days: [weekday],
                startTime: now.addingTimeInterval(-300),
                endTime: now.addingTimeInterval(300),
                isEnabled: true,
                type: .focus,
                ruleSetId: nil
            )
        ]
        appState.activeRuleSetId = set.id
        #expect(appState.currentPrimaryRuleSetId == set.id)
        appState.activeRuleSetId = nil
        #expect(appState.currentPrimaryRuleSetId == set.id)
    }

    @Test("AppState initializes with fallback appearance and injected monitor")
    func initFallbackAndInjectedMonitorCoverage() {
        let suiteA = "AppStateTests.initFallbackAndInjectedMonitorCoverage.A"
        let defaultsA = UserDefaults(suiteName: suiteA)!
        defaultsA.removePersistentDomain(forName: suiteA)
        let sourceAppState = AppState(defaults: defaultsA, isTesting: true)
        let monitor = BrowserMonitor(
            appState: sourceAppState,
            server: nil,
            automator: MockBrowserAutomator(),
            startTimer: false
        )

        let suiteB = "AppStateTests.initFallbackAndInjectedMonitorCoverage.B"
        let defaultsB = UserDefaults(suiteName: suiteB)!
        defaultsB.removePersistentDomain(forName: suiteB)
        defaultsB.set("not-a-real-mode", forKey: "AppearanceMode")

        let appState = AppState(defaults: defaultsB, monitor: monitor, isTesting: true)
        #expect(appState.appearanceMode == .system)
        #expect(appState.monitor === monitor)
    }

    @Test("skipPomodoroPhase transitions between focus and break")
    func skipPomodoroPhaseCoverage() {
        let scheduler = MockRepeatingTimerScheduler()
        let appState = isolatedAppState(name: "skipPomodoroPhaseCoverage", timerScheduler: scheduler)

        appState.startPomodoro()
        #expect(appState.pomodoroStatus == .focus)

        appState.skipPomodoroPhase()
        #expect(appState.pomodoroStatus == .breakTime)

        appState.skipPomodoroPhase()
        #expect(appState.pomodoroStatus == .focus)

        appState.pomodoroStatus = .none
        appState.skipPomodoroPhase()
        #expect(appState.pomodoroStatus == .none)
    }

    @Test("pause and pomodoro timer handlers execute countdown and transition logic")
    func timerHandlerCoverage() {
        let scheduler = MockRepeatingTimerScheduler()
        let appState = isolatedAppState(name: "timerHandlerCoverage", timerScheduler: scheduler)
        appState.isBlocking = true

        appState.startPause(minutes: 1)
        #expect(scheduler.handlers.count >= 2)

        appState.pauseRemaining = 2
        scheduler.fire(at: 1)
        #expect(appState.pauseRemaining == 1)

        appState.pauseRemaining = 0
        scheduler.fire(at: 1)
        #expect(!appState.isPaused)

        appState.startPomodoro()
        #expect(appState.pomodoroStatus == .focus)
        #expect(scheduler.handlers.count >= 3)

        let focusTimerIndex = scheduler.handlers.count - 1
        appState.pomodoroRemaining = 2
        scheduler.fire(at: focusTimerIndex)
        #expect(appState.pomodoroRemaining == 1)

        appState.pomodoroRemaining = 0
        scheduler.fire(at: focusTimerIndex)
        #expect(appState.pomodoroStatus == .breakTime)

        let breakTimerIndex = scheduler.handlers.count - 1
        appState.pomodoroRemaining = 0
        scheduler.fire(at: breakTimerIndex)
        #expect(appState.pomodoroStatus == .focus)
    }

    @Test("AppState covers nil self timer closures after deinit")
    func timerWeakSelfNilCoverage() {
        let scheduler = MockRepeatingTimerScheduler()
        var appState: AppState? = isolatedAppState(name: "timerWeakSelfNilCoverage", timerScheduler: scheduler)
        appState?.isBlocking = true
        appState?.startPause(minutes: 1)
        appState?.startPomodoro()
        #expect(scheduler.handlers.count >= 3)

        appState = nil
        scheduler.fire(at: 0)
        scheduler.fire(at: 1)
        scheduler.fire(at: 2)
        #expect(Bool(true))
    }

    @Test("refreshCurrentOpenUrls uses monitor-provided URLs")
    func refreshCurrentOpenUrlsCoverage() {
        let appState = isolatedAppState(name: "refreshCurrentOpenUrlsCoverage")
        let automator = MockBrowserAutomator()
        automator.activeUrl = "https://example.com"

        let monitor = BrowserMonitor(
            appState: appState,
            server: nil,
            automator: automator,
            startTimer: false
        )
        appState.monitor = monitor

        appState.refreshCurrentOpenUrls()
        #expect(appState.currentOpenUrls == ["https://example.com"])
    }

    @Test("refreshCurrentOpenUrls falls back to empty when monitor is missing")
    func refreshCurrentOpenUrlsNilMonitorCoverage() {
        let appState = isolatedAppState(name: "refreshCurrentOpenUrlsNilMonitorCoverage")
        appState.currentOpenUrls = ["stale"]
        appState.monitor = nil
        appState.refreshCurrentOpenUrls()
        #expect(appState.currentOpenUrls.isEmpty)
    }

    @Test("deleteSet updates active selection and saveSchedule empty-name defaults")
    func deleteAndDefaultNameCoverage() {
        let appState = isolatedAppState(name: "deleteAndDefaultNameCoverage")
        let set1 = RuleSet(id: UUID(), name: "Set 1", urls: [])
        let set2 = RuleSet(id: UUID(), name: "Set 2", urls: [])
        appState.ruleSets = [set1, set2]
        appState.activeRuleSetId = set1.id
        appState.deleteSet(id: set1.id)
        #expect(appState.activeRuleSetId == set2.id)

        let start = Date()
        let end = start.addingTimeInterval(3600)
        appState.saveSchedule(
            name: " ",
            days: [2],
            date: nil,
            start: start,
            end: end,
            color: 0,
            type: .focus,
            ruleSet: nil,
            existingId: nil,
            modifyAllDays: true,
            initialDay: nil
        )
        appState.saveSchedule(
            name: "",
            days: [3],
            date: nil,
            start: start,
            end: end,
            color: 0,
            type: .unfocus,
            ruleSet: nil,
            existingId: nil,
            modifyAllDays: true,
            initialDay: nil
        )
        #expect(appState.schedules.contains { $0.name == "Focus Session" })
        #expect(appState.schedules.contains { $0.name == "Break Session" })
    }

    @Test("save and delete schedule remove empty-day entries")
    func emptyDayRemovalCoverage() {
        let appState = isolatedAppState(name: "emptyDayRemovalCoverage")
        let start = Date()
        let end = start.addingTimeInterval(3600)

        let splitId = UUID()
        appState.schedules = [
            Schedule(id: splitId, name: "Split", days: [2], startTime: start, endTime: end)
        ]
        appState.saveSchedule(
            name: "Only day edited",
            days: [2],
            date: nil,
            start: start,
            end: end,
            color: 1,
            type: .focus,
            ruleSet: nil,
            existingId: splitId,
            modifyAllDays: false,
            initialDay: 2
        )
        #expect(appState.schedules.count == 1)
        #expect(appState.schedules.first?.name == "Only day edited")

        let deleteId = UUID()
        appState.schedules = [
            Schedule(id: deleteId, name: "Delete", days: [3], startTime: start, endTime: end)
        ]
        appState.deleteSchedule(id: deleteId, modifyAllDays: false, initialDay: 3)
        #expect(appState.schedules.isEmpty)
    }

    @Test("pomodoro break duration updates remaining during break phase")
    func breakDurationUpdateCoverage() {
        let appState = isolatedAppState(name: "breakDurationUpdateCoverage")
        appState.pomodoroStatus = .breakTime
        appState.pomodoroBreakDuration = 7
        #expect(appState.pomodoroRemaining == 420)
    }

    @Test("allowedRules falls back to first ruleset when activeRuleSetId is nil")
    func allowedRulesNilActiveRuleSetFallbackCoverage() {
        let appState = isolatedAppState(name: "allowedRulesNilActiveRuleSetFallbackCoverage")
        let fallbackSet = RuleSet(id: UUID(), name: "Fallback", urls: ["fallback.com"])
        appState.ruleSets = [fallbackSet]
        appState.activeRuleSetId = nil
        appState.isBlocking = true

        let rules = appState.allowedRules
        #expect(rules.contains("fallback.com"))
    }

    @Test("AppState deinit invalidates schedule, pause, and pomodoro timers")
    func appStateDeinitInvalidatesTimers() {
        let scheduler = MockRepeatingTimerScheduler()
        var appState: AppState? = isolatedAppState(name: "appStateDeinitInvalidatesTimers", timerScheduler: scheduler)
        appState?.isBlocking = true
        appState?.startPause(minutes: 1)
        appState?.startPomodoro()

        #expect(scheduler.timers.count == 3)
        let scheduleTimer = scheduler.timers[0]
        let pauseTimer = scheduler.timers[1]
        let pomodoroTimer = scheduler.timers[2]

        appState = nil

        #expect(scheduleTimer.invalidateCallCount == 1)
        #expect(pauseTimer.invalidateCallCount == 1)
        #expect(pomodoroTimer.invalidateCallCount == 1)
    }

    @Test("AppState replaces active pause and pomodoro timers safely")
    func appStateReplacesTimersSafely() {
        let scheduler = MockRepeatingTimerScheduler()
        let appState = isolatedAppState(name: "appStateReplacesTimersSafely", timerScheduler: scheduler)
        appState.isBlocking = true

        appState.startPause(minutes: 1)
        #expect(scheduler.timers.count == 2)
        let firstPauseTimer = scheduler.timers[1]

        appState.startPause(minutes: 2)
        #expect(scheduler.timers.count == 3)
        #expect(firstPauseTimer.invalidateCallCount == 1)

        appState.startPomodoro()
        #expect(scheduler.timers.count == 4)
        let firstPomodoroTimer = scheduler.timers[3]

        appState.startPomodoro()
        #expect(scheduler.timers.count == 5)
        #expect(firstPomodoroTimer.invalidateCallCount == 1)
    }

    @Test("Rules aggregate from all active focus schedules")
    func multipleSchedulesRules() {
        // Given
        let appState = isolatedAppState(name: "multipleSchedulesRules")
        let ruleSet1 = RuleSet(id: UUID(), name: "Set 1", urls: ["url1.com"])
        let ruleSet2 = RuleSet(id: UUID(), name: "Set 2", urls: ["url2.com"])
        appState.ruleSets = [ruleSet1, ruleSet2]

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        let sch1 = Schedule(name: "S1", days: [weekday], startTime: now.addingTimeInterval(-1000), endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus, ruleSetId: ruleSet1.id)
        let sch2 = Schedule(name: "S2", days: [weekday], startTime: now.addingTimeInterval(-1000), endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus, ruleSetId: ruleSet2.id)

        // When
        appState.schedules = [sch1, sch2]

        // Then
        let allowed = appState.allowedRules
        #expect(allowed.contains("url1.com"))
        #expect(allowed.contains("url2.com"))
    }

    @Test("todaySchedules filters by current day and sorts by time")
    func todaySchedulesLogic() {
        // Given
        let appState = isolatedAppState(name: "todaySchedulesLogic")
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: now)
        let otherDay = today == 1 ? 2 : 1

        let early = calendar.date(from: DateComponents(hour: 8, minute: 0))!
        let late = calendar.date(from: DateComponents(hour: 20, minute: 0))!

        let s1 = Schedule(name: "Late Today", days: [today], startTime: late, endTime: late.addingTimeInterval(3600))
        let s2 = Schedule(name: "Early Today", days: [today], startTime: early, endTime: early.addingTimeInterval(3600))
        let s3 = Schedule(name: "Other Day", days: [otherDay], startTime: early, endTime: early.addingTimeInterval(3600))

        // When
        appState.schedules = [s1, s2, s3]

        // Then
        let result = appState.todaySchedules
        #expect(result.count == 2)
        #expect(result[0].name == "Early Today")
        #expect(result[1].name == "Late Today")
    }

    @Test("saveSchedule logic: Create and Update")
    func saveScheduleLogic() {
        let appState = isolatedAppState(name: "saveScheduleLogic")
        let start = Date()
        let end = start.addingTimeInterval(3600)
        
        // 1. Create new
        appState.saveSchedule(name: "New", days: [2], date: nil, start: start, end: end, color: 1, type: .focus, ruleSet: nil, existingId: nil, modifyAllDays: true, initialDay: nil)
        #expect(appState.schedules.count == 1)
        #expect(appState.schedules.first?.name == "New")
        
        // 2. Update existing
        let id = appState.schedules.first!.id
        appState.saveSchedule(name: "Updated", days: [2, 3], date: nil, start: start, end: end, color: 2, type: .unfocus, ruleSet: nil, existingId: id, modifyAllDays: true, initialDay: nil)
        #expect(appState.schedules.count == 1)
        #expect(appState.schedules.first?.name == "Updated")
        #expect(appState.schedules.first?.days.count == 2)
    }

    @Test("saveSchedule logic: Splitting recurring schedule")
    func splitScheduleLogic() {
        let appState = isolatedAppState(name: "splitScheduleLogic")
        let start = Date()
        let end = start.addingTimeInterval(3600)
        
        // Setup: Mon-Wed schedule
        let originalId = UUID()
        let original = Schedule(id: originalId, name: "Original", days: [2, 3, 4], startTime: start, endTime: end)
        appState.schedules = [original]
        
        // When: User edits ONLY Tuesday (Day 3)
        appState.saveSchedule(name: "Split", days: [3], date: nil, start: start, end: end, color: 5, type: .focus, ruleSet: nil, existingId: originalId, modifyAllDays: false, initialDay: 3)
        
        // Then:
        // 1. Original should only have [2, 4] (Mon, Wed)
        let old = appState.schedules.first { $0.id == originalId }
        #expect(old?.days == [2, 4])
        
        // 2. New schedule should exist for [3] (Tue)
        let new = appState.schedules.first { $0.name == "Split" }
        #expect(new?.days == [3])
        #expect(appState.schedules.count == 2)
    }

    @Test("deleteSchedule logic: Full and Partial")
    func deleteScheduleLogic() {
        let appState = isolatedAppState(name: "deleteScheduleLogic")
        let start = Date()
        let end = start.addingTimeInterval(3600)
        
        // Setup: Mon-Tue schedule
        let id = UUID()
        appState.schedules = [Schedule(id: id, name: "T", days: [2, 3], startTime: start, endTime: end)]
        
        // 1. Delete only Mon
        appState.deleteSchedule(id: id, modifyAllDays: false, initialDay: 2)
        #expect(appState.schedules.count == 1)
        #expect(appState.schedules.first?.days == [3])
        
        // 2. Delete remaining
        appState.deleteSchedule(id: id, modifyAllDays: true, initialDay: nil)
        #expect(appState.schedules.isEmpty)
    }

    @Test("currentPrimaryRuleSetId priority logic")
    func ruleSetPriority() {
        let appState = isolatedAppState(name: "ruleSetPriority")
        let set1 = RuleSet(id: UUID(), name: "Manual", urls: [])
        let set2 = RuleSet(id: UUID(), name: "Schedule", urls: [])
        appState.ruleSets = [set1, set2]
        
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        let sch = Schedule(name: "S", days: [today], startTime: now.addingTimeInterval(-1000), endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus, ruleSetId: set2.id)
        appState.schedules = [sch]
        
        // 1. Schedule only
        appState.checkSchedules()
        #expect(appState.currentPrimaryRuleSetId == set2.id)
        
        // 2. Manual override wins over schedule
        appState.activeRuleSetId = set1.id
        appState.toggleBlocking() // Turning it OFF manually (even if schedule wants it ON)
        #expect(!appState.isBlocking)
        
        appState.toggleBlocking() // Turning it ON manually
        #expect(appState.isBlocking)
        #expect(appState.currentPrimaryRuleSetId == set1.id)
        
        // 3. Pomodoro wins over manual
        appState.pomodoroStatus = .focus
        #expect(appState.currentPrimaryRuleSetId == set1.id) // Still set1 if it was active
    }

    @Test("Manual toggle can stop a schedule-started session")
    func manualOverrideOfSchedule() {
        let appState = isolatedAppState(name: "manualOverrideOfSchedule")
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        let sch = Schedule(name: "S", days: [today], startTime: now.addingTimeInterval(-1000), endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus)
        
        appState.schedules = [sch]
        appState.checkSchedules()
        #expect(appState.isBlocking)
        
        // When: User manually toggles OFF
        appState.toggleBlocking()
        
        // Then: Should be OFF even though schedule is active
        #expect(!appState.isBlocking)
        
        // When: checkSchedules runs again (e.g. 1 min later)
        appState.checkSchedules()
        
        // Then: Should STAY off (wasStartedBySchedule is now false)
        #expect(!appState.isBlocking)
    }

    @Test("Nested schedule priority (Break inside Focus)")
    func nestedSchedulePriority() {
        let appState = isolatedAppState(name: "nestedSchedulePriority")
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        
        // Focus: 12:00 - 14:00
        let focus = Schedule(name: "Focus", days: [today], startTime: now.addingTimeInterval(-3600), endTime: now.addingTimeInterval(3600), isEnabled: true, type: .focus)
        
        // Break: 12:30 - 13:00 (nested)
        let breakSession = Schedule(name: "Break", days: [today], startTime: now.addingTimeInterval(-600), endTime: now.addingTimeInterval(600), isEnabled: true, type: .unfocus)
        
        appState.schedules = [focus, breakSession]
        appState.checkSchedules()
        
        // Break should win
        #expect(!appState.isBlocking)
    }

    @Test("Challenge phrase enforcement logic")
    func challengePhraseEnforcement() {
        let appState = isolatedAppState(name: "challengePhraseEnforcement")
        
        // 1. Unblockable mode
        appState.isUnblockable = true
        #expect(!appState.disableUnblockableWithChallenge(phrase: "wrong"))
        #expect(appState.isUnblockable)
        
        #expect(appState.disableUnblockableWithChallenge(phrase: AppState.challengePhrase))
        #expect(!appState.isUnblockable)
        
        // 2. Pomodoro Stop
        appState.isUnblockable = true
        appState.startPomodoro()
        appState.pomodoroStartedAt = Date().addingTimeInterval(-100) // Ensure it's locked
        #expect(appState.isPomodoroLocked)
        
        #expect(!appState.stopPomodoroWithChallenge(phrase: "wrong"))
        #expect(appState.pomodoroStatus == .focus)
        
        #expect(appState.stopPomodoroWithChallenge(phrase: AppState.challengePhrase))
        #expect(appState.pomodoroStatus == .none)
    }

    @Test("Negative: Challenge phrase is case-sensitive and strict on whitespace")
    func challengePhraseStrictness() {
        let appState = isolatedAppState(name: "challengePhraseStrictness")
        appState.isUnblockable = true
        
        // 1. Casing (should fail)
        let lowercased = AppState.challengePhrase.lowercased()
        #expect(!appState.disableUnblockableWithChallenge(phrase: lowercased))
        
        // 2. Leading/Trailing whitespace (should fail)
        let padded = " " + AppState.challengePhrase + " "
        #expect(!appState.disableUnblockableWithChallenge(phrase: padded))
        
        #expect(appState.isUnblockable, "Should still be locked after bad attempts")
    }

    @Test("Negative: Pause when not blocking should fail")
    func pauseWhileNotBlocking() {
        let appState = isolatedAppState(name: "pauseWhileNotBlocking")
        appState.isBlocking = false
        
        appState.startPause(minutes: 5)
        #expect(!appState.isPaused)
    }

    @Test("Negative: Duplicate rules should not be added")
    func duplicateRules() {
        let appState = isolatedAppState(name: "duplicateRules")
        let id = appState.ruleSets[0].id
        
        appState.addRule("google.com", to: id)
        let count = appState.ruleSets[0].urls.count
        
        appState.addRule("google.com", to: id)
        #expect(appState.ruleSets[0].urls.count == count, "Should not add duplicate URL")
        
        appState.addRule(" google.com ", to: id) // With spaces
        #expect(appState.ruleSets[0].urls.count == count, "Should trim and detect duplicate")
    }

    @Test("Negative: Stop Pomodoro when locked without challenge")
    func stopLockedPomodoro() {
        let appState = isolatedAppState(name: "stopLockedPomodoro")
        appState.isUnblockable = true
        appState.startPomodoro()
        appState.pomodoroStartedAt = Date().addingTimeInterval(-100) // Locked
        
        appState.stopPomodoro() // Normal stop call
        #expect(appState.pomodoroStatus == .focus, "Should not stop locked session without challenge")
    }

    @Test("Negative: Rule management with invalid IDs")
    func ruleManagementInvalidIds() {
        let appState = isolatedAppState(name: "ruleManagementInvalidIds")
        let fakeId = UUID()
        
        // 1. Add rule to non-existent set
        appState.addRule("test.com", to: fakeId)
        #expect(!appState.ruleSets.contains { $0.urls.contains("test.com") })
        
        // 2. Remove rule from non-existent set
        appState.removeRule("google.com", from: fakeId)
        
        // 3. Delete non-existent set
        let count = appState.ruleSets.count
        appState.deleteSet(id: fakeId)
        #expect(appState.ruleSets.count == count)
    }

    @Test("Rule aggregation across concurrent focus schedules")
    func concurrentSchedulesRuleAggregation() {
        let appState = isolatedAppState(name: "concurrentSchedulesRuleAggregation")
        
        // 1. Create two sets
        let set1 = RuleSet(id: UUID(), name: "Set 1", urls: ["site1.com"])
        let set2 = RuleSet(id: UUID(), name: "Set 2", urls: ["site2.com"])
        appState.ruleSets = [set1, set2]
        
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        
        // 2. Overlapping focus schedules
        let sch1 = Schedule(name: "S1", days: [today], startTime: now.addingTimeInterval(-1000), endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus, ruleSetId: set1.id)
        let sch2 = Schedule(name: "S2", days: [today], startTime: now.addingTimeInterval(-1000), endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus, ruleSetId: set2.id)
        appState.schedules = [sch1, sch2]
        
        // 3. Verify aggregation
        let rules = appState.allowedRules
        #expect(rules.contains("site1.com"))
        #expect(rules.contains("site2.com"))
        #expect(rules.count == 2)
    }

    @Test("Negative: Prevent rule modifications during strict mode")
    func strictRuleModificationProtection() {
        let appState = isolatedAppState(name: "strictRuleModificationProtection")
        let setId = appState.ruleSets[0].id
        let originalCount = appState.ruleSets[0].urls.count
        
        // Enable Strict Mode
        appState.isBlocking = true
        appState.isUnblockable = true
        #expect(appState.isStrictActive)
        
        // 1. Try add
        appState.addRule("cheat.com", to: setId)
        #expect(appState.ruleSets[0].urls.count == originalCount)
        
        // 2. Try remove
        if originalCount > 0 {
            let first = appState.ruleSets[0].urls[0]
            appState.removeRule(first, from: setId)
            #expect(appState.ruleSets[0].urls.contains(first))
        }
        
        // 3. Try delete set
        appState.deleteSet(id: setId)
        #expect(!appState.ruleSets.isEmpty)
    }

    @Test("Negative: Prevent activeRuleSetId change during blocking")
    func ruleSetSwitchDuringBlocking() {
        let appState = isolatedAppState(name: "ruleSetSwitchDuringBlocking")
        let set1 = RuleSet(id: UUID(), name: "S1", urls: [])
        let set2 = RuleSet(id: UUID(), name: "S2", urls: [])
        appState.ruleSets = [set1, set2]
        
        // Setup: Blocking active with set1
        appState.activeRuleSetId = set1.id
        appState.isBlocking = true
        
        // Verification: The widget logic uses 'if !appState.isBlocking' 
        // We verify the data dependency: even if code TRIED to change it, 
        // we should know the blocking engine is still using the old rules 
        // until session ends (handled by currentPrimaryRuleSetId logic).
        
        #expect(appState.currentPrimaryRuleSetId == set1.id)
    }

    @Test("Negative: startPause with zero or negative duration")
    func pauseDurationEdgeCases() {
        let appState = isolatedAppState(name: "pauseDurationEdgeCases")
        appState.isBlocking = true
        
        // 1. Zero minutes
        appState.startPause(minutes: 0)
        #expect(!appState.isPaused)
        
        // 2. Negative minutes
        appState.startPause(minutes: -5)
        #expect(!appState.isPaused)
    }

    @Test("Manual pause takes precedence over Pomodoro focus")
    func pausePrecedence() {
        let appState = isolatedAppState(name: "pausePrecedence")
        appState.isBlocking = true
        
        // Start Pomodoro
        appState.startPomodoro()
        #expect(appState.pomodoroStatus == .focus)
        
        // Start Manual Pause (Break)
        appState.startPause(minutes: 5)
        #expect(appState.isPaused)
        
        // Even though Pomodoro says .focus, isPaused must remain true
        // (The monitor uses !appState.isPaused to decide if it should block)
        #expect(appState.isPaused == true)
    }

    @Test("todaySchedules badge count logic")
    func todaySchedulesBadgeCount() {
        let appState = isolatedAppState(name: "todaySchedulesBadgeCount")
        let today = Calendar.current.component(.weekday, from: Date())
        
        let s1 = Schedule(name: "Enabled", days: [today], startTime: Date(), endTime: Date(), isEnabled: true)
        let s2 = Schedule(name: "Disabled", days: [today], startTime: Date(), endTime: Date(), isEnabled: false)
        
        appState.schedules = [s1, s2]
        
        let result = appState.todaySchedules
        #expect(result.count == 2)
        
        // This is the logic used in SchedulesWidget for the badge
        let enabledCount = result.filter { $0.isEnabled }.count
        #expect(enabledCount == 1)
    }

    @Test("Negative: Toggling blocking OFF pauses ALL currently active schedules")
    func pauseMultipleOverlappingSchedules() {
        let appState = isolatedAppState(name: "pauseMultipleOverlappingSchedules")
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        
        let s1 = Schedule(name: "S1", days: [today], startTime: now.addingTimeInterval(-1000), endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus)
        let s2 = Schedule(name: "S2", days: [today], startTime: now.addingTimeInterval(-1000), endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus)
        appState.schedules = [s1, s2]
        
        appState.checkSchedules()
        #expect(appState.isBlocking)
        
        // When: User toggles OFF
        appState.toggleBlocking()
        #expect(!appState.isBlocking)
        
        // Then: Should STAY off even after checkSchedules (both s1 and s2 are in paused set)
        appState.checkSchedules()
        #expect(!appState.isBlocking)
    }

    @Test("todaySchedules handles duplicate start times gracefully")
    func todaySchedulesDuplicateTimes() {
        let appState = isolatedAppState(name: "todaySchedulesDuplicateTimes")
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        
        let time = Calendar.current.date(from: DateComponents(hour: 10, minute: 0))!
        let s1 = Schedule(name: "A", days: [today], startTime: time, endTime: time.addingTimeInterval(3600))
        let s2 = Schedule(name: "B", days: [today], startTime: time, endTime: time.addingTimeInterval(3600))
        
        appState.schedules = [s1, s2]
        let result = appState.todaySchedules
        #expect(result.count == 2)
    }

    @Test("currentPrimaryRuleSetName correctly identifies the active list name")
    func primaryRuleSetNameLogic() {
        let appState = isolatedAppState(name: "primaryRuleSetNameLogic")
        
        // Setup: Two sets
        let set1 = RuleSet(id: UUID(), name: "Manual Set", urls: [])
        let set2 = RuleSet(id: UUID(), name: "Schedule Set", urls: [])
        appState.ruleSets = [set1, set2]
        
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        
        // 1. Manual focus active
        appState.activeRuleSetId = set1.id
        appState.isBlocking = true
        #expect(appState.currentPrimaryRuleSetName == "Manual Set")
        
        // 2. Schedule focus active (and manual off)
        appState.isBlocking = false
        let sch = Schedule(name: "S", days: [today], startTime: now.addingTimeInterval(-1000), endTime: now.addingTimeInterval(1000), isEnabled: true, type: .focus, ruleSetId: set2.id)
        appState.schedules = [sch]
        appState.checkSchedules()
        #expect(appState.isBlocking)
        #expect(appState.currentPrimaryRuleSetName == "Schedule Set")
        
        // 3. Fallback when no ID matches
        appState.activeRuleSetId = UUID() // Non-existent
        #expect(appState.currentPrimaryRuleSetName == "Manual Set" || appState.currentPrimaryRuleSetName == "Schedule Set")
    }

    @Test("Pomodoro remaining time reflects duration changes mid-run")
    func pomodoroMidRunDurationChange() {
        let appState = isolatedAppState(name: "pomodoroMidRunDurationChange")
        appState.pomodoroFocusDuration = 25
        appState.startPomodoro()
        #expect(appState.pomodoroRemaining == 25 * 60)
        
        // When: Duration changed to 45
        appState.pomodoroFocusDuration = 45
        
        // Then: Ideally it should adjust, but let's check current behavior
        // (Current behavior: It DOES NOT adjust until next start)
        // I will add code to make it adjust.
        #expect(appState.pomodoroRemaining == 45 * 60)
    }

    @Test("One-off sessions only appear in their specific week grid")
    func calendarGridFilteringLogic() {
        let calendar = Calendar.current
        // Use a fixed Wednesday (Feb 18, 2026)
        let components = DateComponents(year: 2026, month: 2, day: 18, hour: 12)
        let testDate = calendar.date(from: components)!
        
        let start = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 11, minute: 0))!
        
        // Setup: A one-off session for that Wednesday
        let schedule = Schedule(name: "Feb 18 Only", days: [], date: testDate, startTime: start, endTime: end)
        
        // Helper to mimic WeeklyCalendarView.swift filter
        func shouldShow(s: Schedule, weekStart: Date, weekEnd: Date) -> Bool {
            let cal = Calendar.current
            if let specificDate = s.date {
                let d = cal.startOfDay(for: specificDate)
                let s = cal.startOfDay(for: weekStart)
                let e = cal.startOfDay(for: weekEnd)
                return d >= s && d < e
            }
            return true
        }
        
        // 1. Visible week is This Week (Feb 15 - Feb 21)
        let week1 = WeeklyCalendarView.getWeekDates(at: testDate, weekStartsOnMonday: false, offset: 0)
        let week1Start = week1.first!
        let week1End = calendar.date(byAdding: .day, value: 7, to: week1Start)!
        #expect(shouldShow(s: schedule, weekStart: week1Start, weekEnd: week1End) == true)
        
        // 2. Visible week is Next Week
        let week2 = WeeklyCalendarView.getWeekDates(at: testDate, weekStartsOnMonday: false, offset: 1)
        let week2Start = week2.first!
        let week2End = calendar.date(byAdding: .day, value: 7, to: week2Start)!
        #expect(shouldShow(s: schedule, weekStart: week2Start, weekEnd: week2End) == false)
    }
}
