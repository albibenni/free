import Foundation
import Testing

@testable import FreeLogic

struct AppStateCalendarSyncCoordinatorTests {
    @Test("rebuildForResync returns nil when calendar integration is disabled")
    func rebuildForResyncDisabledIntegration() {
        let result = AppStateCalendarSyncCoordinator.rebuildForResync(
            calendarIntegrationEnabled: false,
            currentSchedules: [],
            events: [],
            calendarImportsBlockTime: true,
            suppressedImportedCalendarEventKeys: [],
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()],
            weekStartsOnMonday: false,
            preservedImportedByKey: [:]
        )

        #expect(result == nil)
    }

    @Test("rebuildForScheduleCheck returns nil while synchronization is in progress")
    func rebuildForScheduleCheckWhileSynchronizing() {
        let result = AppStateCalendarSyncCoordinator.rebuildForScheduleCheck(
            isSynchronizingImportedSchedules: true,
            currentSchedules: [],
            events: [],
            calendarIntegrationEnabled: true,
            calendarImportsBlockTime: true,
            suppressedImportedCalendarEventKeys: [],
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()],
            weekStartsOnMonday: false,
            preservedImportedByKey: [:]
        )

        #expect(result == nil)
    }

    @Test("rebuildForResync returns rebuilt schedules when importable event changes state")
    func rebuildForResyncReturnsMergedSchedules() {
        let now = Date()
        let event = ExternalEvent(
            id: "event-1",
            title: "Event",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600)
        )

        let result = AppStateCalendarSyncCoordinator.rebuildForResync(
            calendarIntegrationEnabled: true,
            currentSchedules: [],
            events: [event],
            calendarImportsBlockTime: true,
            suppressedImportedCalendarEventKeys: [],
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()],
            weekStartsOnMonday: false,
            preservedImportedByKey: [:]
        )

        #expect(result?.isEmpty == false)
        #expect(result?.first?.importedCalendarEventKey != nil)
    }
}
