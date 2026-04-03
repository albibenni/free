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
        pomodoroStatus: PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isStrict: Bool,
        calendarEvents: [ExternalEvent]
    ) -> Result {
        let blocking = AppStateBlockingCoordinator.evaluateAutomaticBlocking(
            schedules: schedules,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isStrict: isStrict,
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
