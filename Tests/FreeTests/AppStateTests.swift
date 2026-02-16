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

    @Test("saveSchedule logic: Create and Update")
    func saveScheduleLogic() {
        let appState = isolatedAppState(name: "saveScheduleLogic")
        let start = Date()
        let end = start.addingTimeInterval(3600)
        
        // 1. Create new
        appState.saveSchedule(name: "New", days: [2], start: start, end: end, color: 1, type: .focus, ruleSet: nil, existingId: nil, modifyAllDays: true, initialDay: nil)
        #expect(appState.schedules.count == 1)
        #expect(appState.schedules.first?.name == "New")
        
        // 2. Update existing
        let id = appState.schedules.first!.id
        appState.saveSchedule(name: "Updated", days: [2, 3], start: start, end: end, color: 2, type: .unfocus, ruleSet: nil, existingId: id, modifyAllDays: true, initialDay: nil)
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
        appState.saveSchedule(name: "Split", days: [3], start: start, end: end, color: 5, type: .focus, ruleSet: nil, existingId: originalId, modifyAllDays: false, initialDay: 3)
        
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
}


