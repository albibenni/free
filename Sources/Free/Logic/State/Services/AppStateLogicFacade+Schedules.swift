import Foundation

extension AppStateLogicFacade {
    func saveSchedule(
        currentSchedules: [Schedule],
        name: String,
        days: Set<Int>,
        date: Date?,
        start: Date,
        end: Date,
        color: Int,
        type: ScheduleType,
        ruleSet: UUID?,
        existingId: UUID?,
        modifyAllDays: Bool,
        initialDay: Int?
    ) -> [Schedule] {
        AppStateScheduleMutationCoordinator.saveSchedule(
            currentSchedules: currentSchedules,
            name: name,
            days: days,
            date: date,
            start: start,
            end: end,
            color: color,
            type: type,
            ruleSet: ruleSet,
            existingId: existingId,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay
        )
    }

    func updateScheduleOccurrence(
        currentSchedules: [Schedule],
        id: UUID,
        originalDay: Int,
        targetDay: Int,
        targetDate: Date?,
        start: Date,
        end: Date
    ) -> [Schedule] {
        AppStateScheduleMutationCoordinator.updateScheduleOccurrence(
            currentSchedules: currentSchedules,
            id: id,
            originalDay: originalDay,
            targetDay: targetDay,
            targetDate: targetDate,
            start: start,
            end: end
        )
    }

    func deleteSchedule(
        currentSchedules: [Schedule],
        id: UUID,
        modifyAllDays: Bool,
        initialDay: Int?,
        suppressedImportedCalendarEventKeys: Set<String>
    ) -> ScheduleDeleteResult {
        AppStateScheduleMutationCoordinator.deleteSchedule(
            currentSchedules: currentSchedules,
            id: id,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys
        )
    }

    func rebuildForResync(
        calendarIntegrationEnabled: Bool,
        currentSchedules: [Schedule],
        events: [ExternalEvent],
        suppressedImportedCalendarEventKeys: Set<String>,
        focusTitleRules: [String],
        breakTitleRules: [String],
        calendarImportedScheduleRuleSetId: UUID? = nil,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        weekStartsOnMonday: Bool,
        preservedImportedByKey: [String: Schedule]
    ) -> [Schedule]? {
        AppStateCalendarSyncCoordinator.rebuildForResync(
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            currentSchedules: currentSchedules,
            events: events,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
            focusTitleRules: focusTitleRules,
            breakTitleRules: breakTitleRules,
            calendarImportedScheduleRuleSetId: calendarImportedScheduleRuleSetId,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets,
            weekStartsOnMonday: weekStartsOnMonday,
            preservedImportedByKey: preservedImportedByKey
        )
    }

    func rebuildForScheduleCheck(
        isSynchronizingImportedSchedules: Bool,
        currentSchedules: [Schedule],
        events: [ExternalEvent],
        calendarIntegrationEnabled: Bool,
        suppressedImportedCalendarEventKeys: Set<String>,
        focusTitleRules: [String],
        breakTitleRules: [String],
        calendarImportedScheduleRuleSetId: UUID? = nil,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        weekStartsOnMonday: Bool,
        preservedImportedByKey: [String: Schedule]
    ) -> [Schedule]? {
        AppStateCalendarSyncCoordinator.rebuildForScheduleCheck(
            isSynchronizingImportedSchedules: isSynchronizingImportedSchedules,
            currentSchedules: currentSchedules,
            events: events,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
            focusTitleRules: focusTitleRules,
            breakTitleRules: breakTitleRules,
            calendarImportedScheduleRuleSetId: calendarImportedScheduleRuleSetId,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets,
            weekStartsOnMonday: weekStartsOnMonday,
            preservedImportedByKey: preservedImportedByKey
        )
    }

    func todaySchedules(from schedules: [Schedule]) -> [Schedule] {
        ScheduleEngine.todaySchedules(from: schedules)
    }
}
