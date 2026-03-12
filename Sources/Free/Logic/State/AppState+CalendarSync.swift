import Foundation

extension AppState {
    private var calendarSyncMutationContext: AppStateCalendarSyncMutationService.Context {
        AppStateCalendarSyncMutationService.Context(
            schedule: scheduleDomainState,
            rules: rulesDomainState,
            settings: settingsDomainState,
            weekStartsOnMonday: settingsDomainState.weekStartsOnMonday,
            events: calendarProvider.events
        )
    }

    private func applyCalendarSyncUpdate(_ update: AppStateCalendarSyncMutationService.Update) {
        applyScheduleDomainState(update.schedule)
    }

    func resyncImportedCalendarSchedules(
        preservedImportedByKey: [String: Schedule] = [:]
    ) {
        guard let update = AppStateCalendarSyncMutationService.resync(
            logicFacade: logicFacade,
            context: calendarSyncMutationContext,
            preservedImportedByKey: preservedImportedByKey
        ) else { return }
        applyCalendarSyncUpdate(update)
    }

    func synchronizeImportedCalendarSchedulesIfNeeded(
        preservedImportedByKey: [String: Schedule] = [:]
    ) {
        guard let update = AppStateCalendarSyncMutationService.synchronizeIfNeeded(
            logicFacade: logicFacade,
            context: calendarSyncMutationContext,
            preservedImportedByKey: preservedImportedByKey
        ) else { return }
        applyCalendarSyncUpdate(update)
    }
}
