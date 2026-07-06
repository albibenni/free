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
                suppressedImportedCalendarEventKeys: scheduleDomainState
                    .suppressedImportedCalendarEventKeys,
                focusTitleRules: settingsDomainState.calendarImportFocusTitleRules,
                breakTitleRules: settingsDomainState.calendarImportBreakTitleRules,
                calendarImportedScheduleRuleSetId: settingsDomainState.calendarImportedScheduleRuleSetId,
                activeRuleSetId: rulesDomainState.activeRuleSetId,
                ruleSets: rulesDomainState.ruleSets,
                weekStartsOnMonday: settingsDomainState.weekStartsOnMonday,
                preservedImportedByKey: preservedImportedByKey
            )
        else { return }
        applyRebuiltImportedSchedules(rebuilt)
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
                suppressedImportedCalendarEventKeys: scheduleDomainState
                    .suppressedImportedCalendarEventKeys,
                focusTitleRules: settingsDomainState.calendarImportFocusTitleRules,
                breakTitleRules: settingsDomainState.calendarImportBreakTitleRules,
                calendarImportedScheduleRuleSetId: settingsDomainState.calendarImportedScheduleRuleSetId,
                activeRuleSetId: rulesDomainState.activeRuleSetId,
                ruleSets: rulesDomainState.ruleSets,
                weekStartsOnMonday: settingsDomainState.weekStartsOnMonday,
                preservedImportedByKey: preservedImportedByKey
            )
        else { return }
        applyRebuiltImportedSchedules(merged)
    }

    private func applyRebuiltImportedSchedules(_ rebuilt: [Schedule]) {
        var state = scheduleDomainState
        state.isSynchronizingImportedSchedules = true
        state.schedules = rebuilt
        state.isSynchronizingImportedSchedules = false
        applyScheduleDomainState(state)
    }
}
