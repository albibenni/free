import Foundation

struct ScheduleCalendarService {
    static func rebuildSchedulesFromCalendarEvents(
        schedules: [Schedule],
        events: [ExternalEvent],
        shouldImportCalendarEvents: Bool,
        suppressedImportedCalendarEventKeys: Set<String>,
        focusTitleRules: [String],
        breakTitleRules: [String],
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        weekStartsOnMonday: Bool,
        preservedImportedByKey: [String: Schedule] = [:]
    ) -> [Schedule] {
        let retainedSchedules = CalendarImportService.pruneSchedulesOlderThanPreviousWeek(
            schedules: schedules,
            weekStartsOnMonday: weekStartsOnMonday
        )
        let retainedEvents = CalendarImportService.pruneCalendarEventsOlderThanPreviousWeek(
            events: events,
            weekStartsOnMonday: weekStartsOnMonday
        )
        let signatures = CalendarImportService.legacyImportedEventSignatures(
            from: retainedEvents
        )

        let cleaned = CalendarImportService.removeLegacyImportedDuplicates(
            from: retainedSchedules,
            signatures: signatures
        )

        return CalendarImportService.mergedSchedulesWithImportedCalendarEvents(
            schedules: cleaned,
            events: retainedEvents,
            shouldImportCalendarEvents: shouldImportCalendarEvents,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
            focusTitleRules: focusTitleRules,
            breakTitleRules: breakTitleRules,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets,
            preservedImportedByKey: preservedImportedByKey
        )
    }

    static func suppressImportedCalendarEventIfNeeded(
        for schedule: Schedule,
        suppressedImportedCalendarEventKeys: inout Set<String>
    ) -> Bool {
        CalendarImportService.suppressImportedCalendarEventIfNeeded(
            for: schedule,
            suppressedKeys: &suppressedImportedCalendarEventKeys
        )
    }
}
