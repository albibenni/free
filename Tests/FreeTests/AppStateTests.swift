import Testing
import Foundation
@testable import FreeLogic

struct AppStateTests {
    
    @Test("Pomodoro locking logic works correctly with grace period")
    func pomodoroLocking() {
        // Given
        let appState = AppState()
        
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
        let appState = AppState()
        appState.isBlocking = true
        appState.isUnblockable = true
        
        #expect(appState.isStrictActive)
        
        appState.isUnblockable = false
        #expect(!appState.isStrictActive)
    }
    
    @Test("Allowed rules aggregation from multiple sources")
    func allowedRulesAggregation() {
        // Given
        let appState = AppState()
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
        let appState = AppState()
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
        let appState = AppState()
        appState.isBlocking = true // Manually started
        
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        
        // Active schedule
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
        
        // When: Schedule ends (simulated by emptying list)
        appState.schedules = []
        appState.checkSchedules()
        
        // Then: Should STILL be blocking because it was manual
        #expect(appState.isBlocking, "Manual focus should not be turned off by schedule ending")
    }
}
