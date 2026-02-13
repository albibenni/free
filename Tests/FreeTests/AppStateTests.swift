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
}
