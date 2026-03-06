import Foundation

extension AppState {
    func deleteSchedule(id: UUID, modifyAllDays: Bool, initialDay: Int?) {
        let result = logicFacade.deleteSchedule(
            currentSchedules: schedules,
            id: id,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys
        )
        guard result.didMutateSchedules else { return }

        suppressedImportedCalendarEventKeys = result.suppressedImportedCalendarEventKeys
        if result.didPersistSuppressedImportedKeys {
            settingsStore.setSuppressedImportedCalendarEventKeys(suppressedImportedCalendarEventKeys)
        }
        schedules = result.schedules
    }

    func saveSchedule(
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
    ) {
        schedules = logicFacade.saveSchedule(
            currentSchedules: schedules,
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
        id: UUID,
        originalDay: Int,
        targetDay: Int,
        targetDate: Date?,
        start: Date,
        end: Date
    ) {
        schedules = logicFacade.updateScheduleOccurrence(
            currentSchedules: schedules,
            id: id,
            originalDay: originalDay,
            targetDay: targetDay,
            targetDate: targetDate,
            start: start,
            end: end
        )
    }
}
