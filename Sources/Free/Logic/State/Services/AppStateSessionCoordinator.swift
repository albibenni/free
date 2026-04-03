import Foundation

enum AppStateSessionCoordinator {
    struct SessionState: Equatable {
        let isBlocking: Bool
        let wasStartedBySchedule: Bool
        let manuallyPausedScheduleIds: Set<UUID>
    }

    static func toggle(
        current: SessionState,
        isStrict: Bool,
        schedules: [Schedule]
    ) -> SessionState {
        let result = BlockingSessionService.toggleBlocking(
            isBlocking: current.isBlocking,
            isStrict: isStrict,
            schedules: schedules,
            manuallyPausedScheduleIds: current.manuallyPausedScheduleIds,
            wasStartedBySchedule: current.wasStartedBySchedule
        )
        return SessionState(
            isBlocking: result.isBlocking,
            wasStartedBySchedule: result.wasStartedBySchedule,
            manuallyPausedScheduleIds: result.manuallyPausedScheduleIds
        )
    }

    static func check(
        current: SessionState,
        schedules: [Schedule],
        pomodoroStatus: PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isStrict: Bool,
        calendarEvents: [ExternalEvent]
    ) -> SessionState {
        let result = AppStateScheduleCheckCoordinator.evaluate(
            currentIsBlocking: current.isBlocking,
            currentWasStartedBySchedule: current.wasStartedBySchedule,
            schedules: schedules,
            manuallyPausedScheduleIds: current.manuallyPausedScheduleIds,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isStrict: isStrict,
            calendarEvents: calendarEvents
        )
        return SessionState(
            isBlocking: result.isBlocking,
            wasStartedBySchedule: result.wasStartedBySchedule,
            manuallyPausedScheduleIds: result.normalizedManuallyPausedScheduleIds
        )
    }

    static func migrateLegacyBlockingSourceIfNeeded(
        hasPersistedWasStartedBySchedule: Bool,
        current: SessionState,
        schedules: [Schedule],
        pomodoroStatus: PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isStrict: Bool,
        calendarEvents: [ExternalEvent]
    ) -> SessionState? {
        let automatic = AppStateBlockingCoordinator.evaluateAutomaticBlocking(
            schedules: schedules,
            manuallyPausedScheduleIds: current.manuallyPausedScheduleIds,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isStrict: isStrict,
            calendarEvents: calendarEvents
        )

        guard
            let migration = AppStateLegacyBlockingMigrationCoordinator.resolve(
                hasPersistedWasStartedBySchedule: hasPersistedWasStartedBySchedule,
                isBlocking: current.isBlocking,
                shouldBeBlockingNow: automatic.shouldBlock
            )
        else { return nil }

        return SessionState(
            isBlocking: migration.isBlocking,
            wasStartedBySchedule: migration.wasStartedBySchedule,
            manuallyPausedScheduleIds: automatic.normalizedManuallyPausedScheduleIds
        )
    }
}
