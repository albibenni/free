import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct AppStatePomodoroCoordinatorTests {
    @Test("timerAction decrements while remaining time is positive")
    func timerActionDecrement() async throws {
        let action = AppStatePomodoroCoordinator.timerAction(
            status: .focus,
            remaining: 1
        )
        #expect(action == .decrement)
    }

    @Test("timerAction switches phase at zero based on current status")
    func timerActionPhaseSwitches() async throws {
        let focusAction = AppStatePomodoroCoordinator.timerAction(
            status: .focus,
            remaining: 0
        )
        let breakAction = AppStatePomodoroCoordinator.timerAction(
            status: .breakTime,
            remaining: 0
        )

        #expect(focusAction == .startBreak)
        #expect(breakAction == .startFocus)
    }

    @Test("stopIfUnlocked returns nil for locked sessions and clears status/ruleset when unlocked")
    func stopIfUnlocked() async throws {
        let running = PomodoroEngine.State(
            status: .focus,
            remaining: 60,
            startedAt: Date(),
            ruleSetId: UUID()
        )

        let locked = AppStatePomodoroCoordinator.stopIfUnlocked(from: running, isLocked: true)
        let unlocked = AppStatePomodoroCoordinator.stopIfUnlocked(from: running, isLocked: false)

        #expect(locked == nil)
        #expect(unlocked?.status == PomodoroStatus.none)
        #expect(unlocked?.remaining == 60)
        #expect(unlocked?.startedAt == running.startedAt)
        #expect(unlocked?.ruleSetId == nil)
    }
}
