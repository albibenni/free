import Foundation

extension AppState {
    var scheduleDomainState: AppScheduleDomainState {
        AppScheduleDomainState(
            schedules: schedules,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            calendarImportsBlockTime: calendarImportsBlockTime,
            isSynchronizingImportedSchedules: isSynchronizingImportedSchedules,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys
        )
    }

    func applyScheduleDomainState(_ state: AppScheduleDomainState) {
        if schedules != state.schedules { schedules = state.schedules }
        if calendarIntegrationEnabled != state.calendarIntegrationEnabled {
            calendarIntegrationEnabled = state.calendarIntegrationEnabled
        }
        if calendarImportsBlockTime != state.calendarImportsBlockTime {
            calendarImportsBlockTime = state.calendarImportsBlockTime
        }
        if isSynchronizingImportedSchedules != state.isSynchronizingImportedSchedules {
            isSynchronizingImportedSchedules = state.isSynchronizingImportedSchedules
        }
        if suppressedImportedCalendarEventKeys != state.suppressedImportedCalendarEventKeys {
            suppressedImportedCalendarEventKeys = state.suppressedImportedCalendarEventKeys
        }
    }
}
