import Foundation

struct AppStateCalendarSyncCoordinator {
    static func rebuildForResync(
        calendarIntegrationEnabled: Bool,
        currentSchedules: [Schedule],
        events: [ExternalEvent],
        calendarImportsBlockTime: Bool,
        suppressedImportedCalendarEventKeys: Set<String>,
        focusTitleRules: [String],
        breakTitleRules: [String],
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        weekStartsOnMonday: Bool,
        preservedImportedByKey: [String: Schedule]
    ) -> [Schedule]? {
        guard calendarIntegrationEnabled else { return nil }
        return AppStateScheduleCoordinator.rebuildIfNeeded(
            currentSchedules: currentSchedules,
            events: events,
            shouldImportCalendarEvents: calendarIntegrationEnabled && calendarImportsBlockTime,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
            focusTitleRules: focusTitleRules,
            breakTitleRules: breakTitleRules,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets,
            weekStartsOnMonday: weekStartsOnMonday,
            preservedImportedByKey: preservedImportedByKey
        )
    }

    static func rebuildForScheduleCheck(
        isSynchronizingImportedSchedules: Bool,
        currentSchedules: [Schedule],
        events: [ExternalEvent],
        calendarIntegrationEnabled: Bool,
        calendarImportsBlockTime: Bool,
        suppressedImportedCalendarEventKeys: Set<String>,
        focusTitleRules: [String],
        breakTitleRules: [String],
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        weekStartsOnMonday: Bool,
        preservedImportedByKey: [String: Schedule]
    ) -> [Schedule]? {
        guard !isSynchronizingImportedSchedules else { return nil }
        return AppStateScheduleCoordinator.rebuildIfNeeded(
            currentSchedules: currentSchedules,
            events: events,
            shouldImportCalendarEvents: calendarIntegrationEnabled && calendarImportsBlockTime,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
            focusTitleRules: focusTitleRules,
            breakTitleRules: breakTitleRules,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets,
            weekStartsOnMonday: weekStartsOnMonday,
            preservedImportedByKey: preservedImportedByKey
        )
    }
}
