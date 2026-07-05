import Foundation

@MainActor
enum AppStateScheduleMutationCoordinator {
    struct DeletionResult {
        let schedules: [Schedule]
        let suppressedImportedCalendarEventKeys: Set<String>
        let didMutateSchedules: Bool
        let didPersistSuppressedImportedKeys: Bool
    }

    static func saveSchedule(
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
        var schedules = currentSchedules
        ScheduleEngine.saveSchedule(
            in: &schedules,
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
        return schedules
    }

    static func updateScheduleOccurrence(
        currentSchedules: [Schedule],
        id: UUID,
        originalDay: Int,
        targetDay: Int,
        targetDate: Date?,
        start: Date,
        end: Date
    ) -> [Schedule] {
        var schedules = currentSchedules
        ScheduleEngine.updateScheduleOccurrence(
            in: &schedules,
            id: id,
            originalDay: originalDay,
            targetDay: targetDay,
            targetDate: targetDate,
            start: start,
            end: end
        )
        return schedules
    }

    static func deleteSchedule(
        currentSchedules: [Schedule],
        id: UUID,
        modifyAllDays: Bool,
        initialDay: Int?,
        suppressedImportedCalendarEventKeys: Set<String>
    ) -> DeletionResult {
        var schedules = currentSchedules
        var suppressedKeys = suppressedImportedCalendarEventKeys
        guard let index = schedules.firstIndex(where: { $0.id == id }) else {
            return DeletionResult(
                schedules: schedules,
                suppressedImportedCalendarEventKeys: suppressedKeys,
                didMutateSchedules: false,
                didPersistSuppressedImportedKeys: false
            )
        }

        if schedules[index].importedCalendarEventKey != nil {
            let deletedSchedule = schedules.remove(at: index)
            let didSuppress = ScheduleCalendarService.suppressImportedCalendarEventIfNeeded(
                for: deletedSchedule,
                suppressedImportedCalendarEventKeys: &suppressedKeys
            )
            return DeletionResult(
                schedules: schedules,
                suppressedImportedCalendarEventKeys: suppressedKeys,
                didMutateSchedules: true,
                didPersistSuppressedImportedKeys: didSuppress
            )
        }

        var didSuppress = false
        if let deletedSchedule = ScheduleEngine.deleteSchedule(
            in: &schedules,
            id: id,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay
        ) {
            didSuppress = ScheduleCalendarService.suppressImportedCalendarEventIfNeeded(
                for: deletedSchedule,
                suppressedImportedCalendarEventKeys: &suppressedKeys
            )
        }

        return DeletionResult(
            schedules: schedules,
            suppressedImportedCalendarEventKeys: suppressedKeys,
            didMutateSchedules: true,
            didPersistSuppressedImportedKeys: didSuppress
        )
    }
}
