import Foundation

struct ScheduleCalendarService {
    static func rebuildSchedulesFromCalendarEvents(
        schedules: [Schedule],
        events: [ExternalEvent],
        shouldImportCalendarEvents: Bool,
        suppressedImportedCalendarEventKeys: Set<String>,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        preservedImportedByKey: [String: Schedule] = [:]
    ) -> [Schedule] {
        let signatures = CalendarImportService.legacyImportedEventSignatures(
            from: events
        )

        let cleaned = CalendarImportService.removeLegacyImportedDuplicates(
            from: schedules,
            signatures: signatures
        )

        return CalendarImportService.mergedSchedulesWithImportedCalendarEvents(
            schedules: cleaned,
            events: events,
            shouldImportCalendarEvents: shouldImportCalendarEvents,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
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
