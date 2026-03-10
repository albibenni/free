import Foundation

struct CalendarImportService {
    struct LegacyImportedEventSignature: Hashable {
        let title: String
        let start: TimeInterval
        let end: TimeInterval
    }

    static func mergedSchedulesWithImportedCalendarEvents(
        schedules: [Schedule],
        events: [ExternalEvent],
        shouldImportCalendarEvents: Bool,
        suppressedImportedCalendarEventKeys: Set<String>,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        preservedImportedByKey: [String: Schedule]
    ) -> [Schedule] {
        let baseSchedules = schedules.filter { $0.importedCalendarEventKey == nil }
        guard shouldImportCalendarEvents else { return baseSchedules }

        let existingImportedByKey: [String: Schedule] = Dictionary(
            uniqueKeysWithValues: schedules.compactMap { schedule in
                guard let key = schedule.importedCalendarEventKey else { return nil }
                return (key, schedule)
            }
        )
        let defaultImportedRuleSetId = RuleSetService.normalizeRuleSetId(activeRuleSetId, in: ruleSets)

        let importedSchedules = events
            .sorted { $0.startDate < $1.startDate }
            .compactMap { event -> Schedule? in
                guard !suppressedImportedCalendarEventKeys.contains(event.id) else { return nil }
                let existing = existingImportedByKey[event.id] ?? preservedImportedByKey[event.id]
                return Schedule(
                    id: existing?.id ?? UUID(),
                    name: event.title,
                    days: [],
                    date: event.startDate,
                    startTime: event.startDate,
                    endTime: event.endDate,
                    isEnabled: existing?.isEnabled ?? true,
                    colorIndex: existing?.colorIndex ?? 0,
                    type: existing?.type ?? .focus,
                    ruleSetId: existing?.ruleSetId ?? defaultImportedRuleSetId,
                    importedCalendarEventKey: event.id
                )
            }

        return baseSchedules + importedSchedules
    }

    static func pruneSchedulesOlderThanPreviousWeek(
        schedules: [Schedule],
        weekStartsOnMonday: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Schedule] {
        let cutoff = previousWeekStart(
            weekStartsOnMonday: weekStartsOnMonday,
            now: now,
            calendar: calendar
        )
        return schedules.filter { schedule in
            guard let specificDate = schedule.date else { return true }
            return specificDate >= cutoff
        }
    }

    static func pruneCalendarEventsOlderThanPreviousWeek(
        events: [ExternalEvent],
        weekStartsOnMonday: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ExternalEvent] {
        let cutoff = previousWeekStart(
            weekStartsOnMonday: weekStartsOnMonday,
            now: now,
            calendar: calendar
        )
        return events.filter { $0.endDate >= cutoff }
    }

    static func legacyImportedEventSignatures(from events: [ExternalEvent]) -> Set<
        LegacyImportedEventSignature
    > {
        Set(
            events.map {
                LegacyImportedEventSignature(
                    title: $0.title,
                    start: $0.startDate.timeIntervalSince1970,
                    end: $0.endDate.timeIntervalSince1970
                )
            }
        )
    }

    static func removeLegacyImportedDuplicates(
        from schedules: [Schedule],
        signatures: Set<LegacyImportedEventSignature>
    ) -> [Schedule] {
        schedules.filter { schedule in
            if schedule.importedCalendarEventKey != nil {
                return false
            }
            return !isLegacyImportedCalendarDuplicate(schedule, signatures: signatures)
        }
    }

    static func suppressImportedCalendarEventIfNeeded(
        for schedule: Schedule,
        suppressedKeys: inout Set<String>
    ) -> Bool {
        guard let key = schedule.importedCalendarEventKey else { return false }
        return suppressedKeys.insert(key).inserted
    }

    private static func isLegacyImportedCalendarDuplicate(
        _ schedule: Schedule,
        signatures: Set<LegacyImportedEventSignature>
    ) -> Bool {
        guard schedule.type == .focus, schedule.date != nil else { return false }
        let signature = LegacyImportedEventSignature(
            title: schedule.name,
            start: schedule.startTime.timeIntervalSince1970,
            end: schedule.endTime.timeIntervalSince1970
        )
        return signatures.contains(signature)
    }

    private static func previousWeekStart(
        weekStartsOnMonday: Bool,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let previousWeek = WeekDateCalculator.getWeekDates(
            at: now,
            weekStartsOnMonday: weekStartsOnMonday,
            offset: -1,
            calendar: calendar
        )
        if let start = previousWeek.first {
            return calendar.startOfDay(for: start)
        }
        return calendar.startOfDay(for: now)
    }
}
