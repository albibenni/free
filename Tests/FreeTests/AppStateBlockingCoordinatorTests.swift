import Foundation
import Testing

@testable import FreeLogic

struct AppStateBlockingCoordinatorTests {
    @Test("evaluateAutomaticBlocking normalizes paused ids and keeps blocking false without active focus")
    func evaluateAutomaticBlockingNoFocus() {
        let result = AppStateBlockingCoordinator.evaluateAutomaticBlocking(
            schedules: [],
            manuallyPausedScheduleIds: [UUID()],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: true,
            isStrict: false,
            calendarImportsBlockTime: false,
            calendarEvents: []
        )

        #expect(result.shouldBlock == false)
        #expect(result.normalizedManuallyPausedScheduleIds.isEmpty)
    }

    @Test("evaluateAutomaticBlocking blocks when pomodoro focus is active and no break overrides")
    func evaluateAutomaticBlockingPomodoroFocus() {
        let result = AppStateBlockingCoordinator.evaluateAutomaticBlocking(
            schedules: [],
            manuallyPausedScheduleIds: [],
            pomodoroStatus: .focus,
            calendarIntegrationEnabled: false,
            isStrict: false,
            calendarImportsBlockTime: false,
            calendarEvents: []
        )

        #expect(result.shouldBlock)
        #expect(result.normalizedManuallyPausedScheduleIds.isEmpty)
    }
}
