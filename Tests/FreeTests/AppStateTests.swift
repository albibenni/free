import Testing
import Foundation
@testable import FreeLogic

struct AppStateTests {

    private func isolatedAppState(name: String) -> AppState {
        let suite = "AppStateTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
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
}


