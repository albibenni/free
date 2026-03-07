import Foundation
import Testing

@testable import FreeLogic

struct AppStateScheduleCheckCoordinatorTests {
    @Test("evaluate starts schedule-driven blocking when automatic focus is active")
    func evaluateStartsBlockingForActiveFocus() {
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        let focus = Schedule(
            name: "Focus",
            days: [today],
            startTime: now.addingTimeInterval(-600),
            endTime: now.addingTimeInterval(600),
            type: .focus
        )

        let result = AppStateScheduleCheckCoordinator.evaluate(
            currentIsBlocking: false,
            currentWasStartedBySchedule: false,
            schedules: [focus],
            manuallyPausedScheduleIds: [],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: false,
            isUnblockable: false,
            calendarImportsBlockTime: false,
            calendarEvents: []
        )

        #expect(result.isBlocking)
        #expect(result.wasStartedBySchedule)
        #expect(result.normalizedManuallyPausedScheduleIds.isEmpty)
    }

    @Test("evaluate stops only schedule-driven blocking when automatic focus is inactive")
    func evaluateStopsOnlyScheduleDrivenBlocking() {
        let result = AppStateScheduleCheckCoordinator.evaluate(
            currentIsBlocking: true,
            currentWasStartedBySchedule: true,
            schedules: [],
            manuallyPausedScheduleIds: [],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: false,
            isUnblockable: false,
            calendarImportsBlockTime: false,
            calendarEvents: []
        )

        #expect(!result.isBlocking)
        #expect(!result.wasStartedBySchedule)
    }

    @Test("evaluate keeps manual blocking active and normalizes stale paused ids")
    func evaluateKeepsManualBlockingAndNormalizesPausedIds() {
        let staleId = UUID()

        let result = AppStateScheduleCheckCoordinator.evaluate(
            currentIsBlocking: true,
            currentWasStartedBySchedule: false,
            schedules: [],
            manuallyPausedScheduleIds: [staleId],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: false,
            isUnblockable: false,
            calendarImportsBlockTime: false,
            calendarEvents: []
        )

        #expect(result.isBlocking)
        #expect(!result.wasStartedBySchedule)
        #expect(result.normalizedManuallyPausedScheduleIds.isEmpty)
    }
}
