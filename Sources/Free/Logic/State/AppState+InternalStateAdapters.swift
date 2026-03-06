import Foundation

extension AppState {
    var wasStartedBySchedule: Bool {
        get { internalState.wasStartedBySchedule }
        set { internalState.wasStartedBySchedule = newValue }
    }

    var manuallyPausedScheduleIds: Set<UUID> {
        get { internalState.manuallyPausedScheduleIds }
        set { internalState.manuallyPausedScheduleIds = newValue }
    }

    var pomodoroRuleSetId: UUID? {
        get { internalState.pomodoroRuleSetId }
        set { internalState.pomodoroRuleSetId = newValue }
    }

    var isSynchronizingImportedSchedules: Bool {
        get { internalState.isSynchronizingImportedSchedules }
        set { internalState.isSynchronizingImportedSchedules = newValue }
    }

    var suppressedImportedCalendarEventKeys: Set<String> {
        get { internalState.suppressedImportedCalendarEventKeys }
        set { internalState.suppressedImportedCalendarEventKeys = newValue }
    }

    func setWasStartedBySchedule(_ value: Bool) {
        wasStartedBySchedule = value
        settingsStore.setWasStartedBySchedule(value)
    }
}
