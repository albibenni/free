import Foundation

struct AppStateInternalState {
    var wasStartedBySchedule = false
    var manualBlockingEnabled = false
    var manuallyPausedScheduleIds: Set<UUID> = []
    var pomodoroRuleSetId: UUID?
    var isSynchronizingImportedSchedules = false
    var suppressedImportedCalendarEventKeys: Set<String> = []
}
