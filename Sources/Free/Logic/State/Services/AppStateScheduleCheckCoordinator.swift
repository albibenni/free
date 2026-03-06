import Foundation

struct AppStateScheduleCheckCoordinator {
    struct Result: Equatable {
        let isBlocking: Bool
        let wasStartedBySchedule: Bool
        let normalizedManuallyPausedScheduleIds: Set<UUID>
    }

    static func evaluate(
        currentIsBlocking: Bool,
        currentWasStartedBySchedule: Bool,
        schedules: [Schedule],
        manuallyPausedScheduleIds: Set<UUID>,
        pomodoroStatus: AppState.PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isUnblockable: Bool,
        calendarImportsBlockTime: Bool,
        calendarEvents: [ExternalEvent]
    ) -> Result {
        let blocking = AppStateBlockingCoordinator.evaluateAutomaticBlocking(
            schedules: schedules,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isUnblockable: isUnblockable,
            calendarImportsBlockTime: calendarImportsBlockTime,
            calendarEvents: calendarEvents
        )

        let transition = BlockingSessionService.scheduleTransition(
            isBlocking: currentIsBlocking,
            wasStartedBySchedule: currentWasStartedBySchedule,
            shouldBeBlocking: blocking.shouldBlock
        )

        return Result(
            isBlocking: transition.isBlocking,
            wasStartedBySchedule: transition.wasStartedBySchedule,
            normalizedManuallyPausedScheduleIds: blocking.normalizedManuallyPausedScheduleIds
        )
    }
}
