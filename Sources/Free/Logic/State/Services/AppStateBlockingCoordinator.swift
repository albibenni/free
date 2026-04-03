import Foundation

struct AppStateBlockingCoordinator {
    struct Result: Equatable {
        let shouldBlock: Bool
        let normalizedManuallyPausedScheduleIds: Set<UUID>
    }

    static func evaluateAutomaticBlocking(
        schedules: [Schedule],
        manuallyPausedScheduleIds: Set<UUID>,
        pomodoroStatus: PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isStrict: Bool,
        calendarEvents: [ExternalEvent]
    ) -> Result {
        let result = ScheduleEngine.automaticBlockingState(
            schedules: schedules,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds,
            pomodoroIsFocus: pomodoroStatus == .focus,
            pomodoroIsBreak: pomodoroStatus == .breakTime,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isStrict: isStrict,
            calendarEvents: calendarEvents
        )

        return Result(
            shouldBlock: result.shouldBlock,
            normalizedManuallyPausedScheduleIds: result.normalizedManuallyPausedScheduleIds
        )
    }
}
