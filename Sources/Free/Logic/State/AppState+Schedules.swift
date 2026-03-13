import Foundation

extension AppState {
    private var schedulesMutationContext: AppStateSchedulesMutationService.Context {
        AppStateSchedulesMutationService.Context(
            schedules: schedules,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys
        )
    }

    private func applySchedulesMutationUpdate(_ update: AppStateSchedulesMutationService.Update) {
        suppressedImportedCalendarEventKeys = update.suppressedImportedCalendarEventKeys
        if update.shouldPersistSuppressedKeys {
            settingsStore.setSuppressedImportedCalendarEventKeys(suppressedImportedCalendarEventKeys)
        }
        schedules = update.schedules
    }

    func deleteSchedule(id: UUID, modifyAllDays: Bool, initialDay: Int?) {
        guard !isUnblockable else { return }
        guard let update = AppStateSchedulesMutationService.deleteSchedule(
            logicFacade: logicFacade,
            context: schedulesMutationContext,
            id: id,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay
        ) else { return }
        applySchedulesMutationUpdate(update)
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
        guard !isUnblockable else { return }
        applySchedulesMutationUpdate(
            AppStateSchedulesMutationService.saveSchedule(
                logicFacade: logicFacade,
                context: schedulesMutationContext,
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
        guard !isUnblockable else { return }
        applySchedulesMutationUpdate(
            AppStateSchedulesMutationService.updateScheduleOccurrence(
                logicFacade: logicFacade,
                context: schedulesMutationContext,
                id: id,
                originalDay: originalDay,
                targetDay: targetDay,
                targetDate: targetDate,
                start: start,
                end: end
            )
        )
    }
}
