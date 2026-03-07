import Foundation

struct AppStateScheduleCoordinator {
    static func rebuildIfNeeded(
        currentSchedules: [Schedule],
        events: [ExternalEvent],
        shouldImportCalendarEvents: Bool,
        suppressedImportedCalendarEventKeys: Set<String>,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        preservedImportedByKey: [String: Schedule] = [:]
    ) -> [Schedule]? {
        let resolvedPreservedImportedByKey = AppStateScheduleCoordinator.preservedImportedByKey(
            from: currentSchedules,
            preferred: preservedImportedByKey
        )

        let rebuilt = ScheduleCalendarService.rebuildSchedulesFromCalendarEvents(
            schedules: currentSchedules,
            events: events,
            shouldImportCalendarEvents: shouldImportCalendarEvents,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets,
            preservedImportedByKey: resolvedPreservedImportedByKey
        )

        return rebuilt == currentSchedules ? nil : rebuilt
    }

    static func preservedImportedByKey(
        from schedules: [Schedule],
        preferred: [String: Schedule] = [:]
    ) -> [String: Schedule] {
        guard preferred.isEmpty else { return preferred }
        return Dictionary(
            uniqueKeysWithValues: schedules.compactMap { schedule in
                guard let key = schedule.importedCalendarEventKey else { return nil }
                return (key, schedule)
            }
        )
    }
}
