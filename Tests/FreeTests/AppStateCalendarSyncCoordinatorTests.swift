import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct AppStateCalendarSyncCoordinatorTests {
    @Test("rebuildForResync returns nil when calendar integration is disabled")
    func rebuildForResyncDisabledIntegration() async throws {
        let result = AppStateCalendarSyncCoordinator.rebuildForResync(
            calendarIntegrationEnabled: false,
            currentSchedules: [],
            events: [],
            suppressedImportedCalendarEventKeys: [],
            focusTitleRules: [],
            breakTitleRules: [],
            calendarImportedScheduleRuleSetId: nil,
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()],
            weekStartsOnMonday: false,
            preservedImportedByKey: [:]
        )

        #expect(result == nil)
    }

    @Test("rebuildForScheduleCheck returns nil while synchronization is in progress")
    func rebuildForScheduleCheckWhileSynchronizing() async throws {
        let result = AppStateCalendarSyncCoordinator.rebuildForScheduleCheck(
            isSynchronizingImportedSchedules: true,
            currentSchedules: [],
            events: [],
            calendarIntegrationEnabled: true,
            suppressedImportedCalendarEventKeys: [],
            focusTitleRules: [],
            breakTitleRules: [],
            calendarImportedScheduleRuleSetId: nil,
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()],
            weekStartsOnMonday: false,
            preservedImportedByKey: [:]
        )

        #expect(result == nil)
    }

    @Test("rebuildForResync returns rebuilt schedules when importable event changes state")
    func rebuildForResyncReturnsMergedSchedules() async throws {
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
            suppressedImportedCalendarEventKeys: [],
            focusTitleRules: [],
            breakTitleRules: [],
            calendarImportedScheduleRuleSetId: nil,
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()],
            weekStartsOnMonday: false,
            preservedImportedByKey: [:]
        )

        #expect(result?.isEmpty == false)
        #expect(result?.first?.importedCalendarEventKey != nil)
    }
}
