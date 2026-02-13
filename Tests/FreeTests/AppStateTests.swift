import XCTest
@testable import FreeLogic

final class AppStateTests: XCTestCase {
    
    // We need to be careful about side effects (UserDefaults, Timer, Server).
    // Ideally AppState should be refactored to allow better testing.
    
    func testPomodoroLocking() {
        // Given
        let appState = AppState()
        
        // When: Start Pomodoro
        appState.isUnblockable = true
        appState.pomodoroStatus = .focus
        appState.pomodoroStartedAt = Date().addingTimeInterval(-100) // Started 100s ago
        
        // Then
        XCTAssertTrue(appState.isPomodoroLocked, "Pomodoro should be locked in strict mode after grace period")
        
        // When: Grace period
        appState.pomodoroStartedAt = Date() // Started just now
        XCTAssertFalse(appState.isPomodoroLocked, "Pomodoro should NOT be locked during grace period")
    }
    
    func testStrictActive() {
        let appState = AppState()
        appState.isBlocking = true
        appState.isUnblockable = true
        
        XCTAssertTrue(appState.isStrictActive)
        
        appState.isUnblockable = false
        XCTAssertFalse(appState.isStrictActive)
    }
    
    func testAllowedRulesAggregation() {
        // Given
        let appState = AppState()
        let ruleSet1 = RuleSet(id: UUID(), name: "Set 1", urls: ["url1.com"])
        let ruleSet2 = RuleSet(id: UUID(), name: "Set 2", urls: ["url2.com"])
        appState.ruleSets = [ruleSet1, ruleSet2]
        
        // When: Manual focus active with Set 1
        appState.isBlocking = true
        appState.activeRuleSetId = ruleSet1.id
        
        // Then
        XCTAssertTrue(appState.allowedRules.contains("url1.com"))
        XCTAssertFalse(appState.allowedRules.contains("url2.com"))
        
        // When: Schedule active with Set 2
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let schedule = Schedule(
            id: UUID(),
            name: "Work",
            days: [weekday],
            startTime: now.addingTimeInterval(-3600), // 1h ago
            endTime: now.addingTimeInterval(3600),    // in 1h
            isEnabled: true,
            type: .focus,
            ruleSetId: ruleSet2.id
        )
        appState.schedules = [schedule]
        appState.checkSchedules() // Trigger update
        
        // Then: Should have both (manual + schedule) if manual is still on, 
        // but checkSchedules might have set wasStartedBySchedule = true.
        // In reality, allowedRules combines all active sources.
        XCTAssertTrue(appState.allowedRules.contains("url2.com"))
    }
    
    func testSchedulePriorityBreakOverridesFocus() {
        // Given
        let appState = AppState()
        // Reset state to ensure clean test environment
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
        XCTAssertFalse(appState.isBlocking, "Blocking should be disabled because an internal Break session is active")
        
        // When: Only Focus active
        appState.schedules = [focusSchedule]
        appState.checkSchedules()
        
        // Then: Should be blocking
        XCTAssertTrue(appState.isBlocking, "Blocking should be enabled when only Focus session is active")
    }
    
    func testManualFocusOverridesScheduleStop() {
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
        
        // When: Schedule ends (simulated by making it inactive)
        appState.schedules = []
        appState.checkSchedules()
        
        // Then: Should STILL be blocking because it was manual (wasStartedBySchedule would be false)
        XCTAssertTrue(appState.isBlocking, "Manual focus should not be turned off by schedule ending")
    }
}
