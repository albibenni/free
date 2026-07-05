import Foundation

@MainActor
enum AppStateSchedulesMutationService {
    struct Context {
        let schedules: [Schedule]
        let suppressedImportedCalendarEventKeys: Set<String>
    }

    struct Update {
        let schedules: [Schedule]
        let suppressedImportedCalendarEventKeys: Set<String>
        let shouldPersistSuppressedKeys: Bool
    }

    static func deleteSchedule(
        logicFacade: AppStateLogicFacade,
        context: Context,
        id: UUID,
        modifyAllDays: Bool,
        initialDay: Int?
    ) -> Update? {
        let result = logicFacade.deleteSchedule(
            currentSchedules: context.schedules,
            id: id,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay,
            suppressedImportedCalendarEventKeys: context.suppressedImportedCalendarEventKeys
        )
        guard result.didMutateSchedules else { return nil }
        return Update(
            schedules: result.schedules,
            suppressedImportedCalendarEventKeys: result.suppressedImportedCalendarEventKeys,
            shouldPersistSuppressedKeys: result.didPersistSuppressedImportedKeys
        )
    }

    static func saveSchedule(
        logicFacade: AppStateLogicFacade,
        context: Context,
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
    ) -> Update {
        Update(
            schedules: logicFacade.saveSchedule(
                currentSchedules: context.schedules,
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
            ),
            suppressedImportedCalendarEventKeys: context.suppressedImportedCalendarEventKeys,
            shouldPersistSuppressedKeys: false
        )
    }

    static func updateScheduleOccurrence(
        logicFacade: AppStateLogicFacade,
        context: Context,
        id: UUID,
        originalDay: Int,
        targetDay: Int,
        targetDate: Date?,
        start: Date,
        end: Date
    ) -> Update {
        Update(
            schedules: logicFacade.updateScheduleOccurrence(
                currentSchedules: context.schedules,
                id: id,
                originalDay: originalDay,
                targetDay: targetDay,
                targetDate: targetDate,
                start: start,
                end: end
            ),
            suppressedImportedCalendarEventKeys: context.suppressedImportedCalendarEventKeys,
            shouldPersistSuppressedKeys: false
        )
    }
}
