import Foundation

enum AppStateCalendarSyncMutationService {
    struct Context {
        let schedule: AppScheduleDomainState
        let rules: AppRulesDomainState
        let settings: AppSettingsDomainState
        let weekStartsOnMonday: Bool
        let events: [ExternalEvent]
    }

    struct Update {
        let schedule: AppScheduleDomainState
    }

    static func resync(
        logicFacade: AppStateLogicFacade,
        context: Context,
        preservedImportedByKey: [String: Schedule]
    ) -> Update? {
        guard
            let rebuilt = logicFacade.rebuildForResync(
                calendarIntegrationEnabled: context.schedule.calendarIntegrationEnabled,
                currentSchedules: context.schedule.schedules,
                events: context.events,
                suppressedImportedCalendarEventKeys: context.schedule
                    .suppressedImportedCalendarEventKeys,
                focusTitleRules: context.settings.calendarImportFocusTitleRules,
                breakTitleRules: context.settings.calendarImportBreakTitleRules,
                calendarImportedScheduleRuleSetId: context.settings.calendarImportedScheduleRuleSetId,
                activeRuleSetId: context.rules.activeRuleSetId,
                ruleSets: context.rules.ruleSets,
                weekStartsOnMonday: context.weekStartsOnMonday,
                preservedImportedByKey: preservedImportedByKey
            )
        else { return nil }

        var state = context.schedule
        state.isSynchronizingImportedSchedules = true
        state.schedules = rebuilt
        state.isSynchronizingImportedSchedules = false
        return Update(schedule: state)
    }

    static func synchronizeIfNeeded(
        logicFacade: AppStateLogicFacade,
        context: Context,
        preservedImportedByKey: [String: Schedule]
    ) -> Update? {
        guard
            let merged = logicFacade.rebuildForScheduleCheck(
                isSynchronizingImportedSchedules: context.schedule.isSynchronizingImportedSchedules,
                currentSchedules: context.schedule.schedules,
                events: context.events,
                calendarIntegrationEnabled: context.schedule.calendarIntegrationEnabled,
                suppressedImportedCalendarEventKeys: context.schedule
                    .suppressedImportedCalendarEventKeys,
                focusTitleRules: context.settings.calendarImportFocusTitleRules,
                breakTitleRules: context.settings.calendarImportBreakTitleRules,
                calendarImportedScheduleRuleSetId: context.settings.calendarImportedScheduleRuleSetId,
                activeRuleSetId: context.rules.activeRuleSetId,
                ruleSets: context.rules.ruleSets,
                weekStartsOnMonday: context.weekStartsOnMonday,
                preservedImportedByKey: preservedImportedByKey
            )
        else { return nil }

        var state = context.schedule
        state.isSynchronizingImportedSchedules = true
        state.schedules = merged
        state.isSynchronizingImportedSchedules = false
        return Update(schedule: state)
    }
}
