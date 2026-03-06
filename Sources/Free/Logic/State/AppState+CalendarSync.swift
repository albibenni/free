import Foundation

extension AppState {
    func resyncImportedCalendarSchedules(
        preservedImportedByKey: [String: Schedule] = [:]
    ) {
        guard
            let rebuilt = logicFacade.rebuildForResync(
                calendarIntegrationEnabled: scheduleDomainState.calendarIntegrationEnabled,
                currentSchedules: scheduleDomainState.schedules,
                events: calendarProvider.events,
                calendarImportsBlockTime: scheduleDomainState.calendarImportsBlockTime,
                suppressedImportedCalendarEventKeys: scheduleDomainState
                    .suppressedImportedCalendarEventKeys,
                activeRuleSetId: rulesDomainState.activeRuleSetId,
                ruleSets: rulesDomainState.ruleSets,
                preservedImportedByKey: preservedImportedByKey
            )
        else { return }

        var state = scheduleDomainState
        state.isSynchronizingImportedSchedules = true
        state.schedules = rebuilt
        state.isSynchronizingImportedSchedules = false
        applyScheduleDomainState(state)
    }

    func synchronizeImportedCalendarSchedulesIfNeeded(
        preservedImportedByKey: [String: Schedule] = [:]
    ) {
        guard
            let merged = logicFacade.rebuildForScheduleCheck(
                isSynchronizingImportedSchedules: scheduleDomainState.isSynchronizingImportedSchedules,
                currentSchedules: scheduleDomainState.schedules,
                events: calendarProvider.events,
                calendarIntegrationEnabled: scheduleDomainState.calendarIntegrationEnabled,
                calendarImportsBlockTime: scheduleDomainState.calendarImportsBlockTime,
                suppressedImportedCalendarEventKeys: scheduleDomainState
                    .suppressedImportedCalendarEventKeys,
                activeRuleSetId: rulesDomainState.activeRuleSetId,
                ruleSets: rulesDomainState.ruleSets,
                preservedImportedByKey: preservedImportedByKey
            )
        else { return }

        var state = scheduleDomainState
        state.isSynchronizingImportedSchedules = true
        state.schedules = merged
        state.isSynchronizingImportedSchedules = false
        applyScheduleDomainState(state)
    }
}
