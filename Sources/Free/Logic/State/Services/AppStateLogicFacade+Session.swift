import Foundation

extension AppStateLogicFacade {
    func makeSessionState(
        isBlocking: Bool,
        wasStartedBySchedule: Bool,
        manuallyPausedScheduleIds: Set<UUID>
    ) -> SessionState {
        SessionState(
            isBlocking: isBlocking,
            wasStartedBySchedule: wasStartedBySchedule,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds
        )
    }

    func migrateLegacyBlockingSourceIfNeeded(
        hasPersistedWasStartedBySchedule: Bool,
        current: SessionState,
        schedules: [Schedule],
        pomodoroStatus: PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isStrict: Bool,
        calendarImportsBlockTime: Bool,
        calendarEvents: [ExternalEvent]
    ) -> SessionState? {
        AppStateSessionCoordinator.migrateLegacyBlockingSourceIfNeeded(
            hasPersistedWasStartedBySchedule: hasPersistedWasStartedBySchedule,
            current: current,
            schedules: schedules,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isStrict: isStrict,
            calendarImportsBlockTime: calendarImportsBlockTime,
            calendarEvents: calendarEvents
        )
    }

    func toggleSession(
        current: SessionState,
        isStrict: Bool,
        schedules: [Schedule]
    ) -> SessionState {
        AppStateSessionCoordinator.toggle(
            current: current,
            isStrict: isStrict,
            schedules: schedules
        )
    }

    func checkSession(
        current: SessionState,
        schedules: [Schedule],
        pomodoroStatus: PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isStrict: Bool,
        calendarImportsBlockTime: Bool,
        calendarEvents: [ExternalEvent]
    ) -> SessionState {
        AppStateSessionCoordinator.check(
            current: current,
            schedules: schedules,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isStrict: isStrict,
            calendarImportsBlockTime: calendarImportsBlockTime,
            calendarEvents: calendarEvents
        )
    }
}
