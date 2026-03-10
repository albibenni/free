import Foundation
import Testing

@testable import FreeLogic

struct AppStateScheduleCoordinatorTests {
    @Test("preservedImportedByKey derives mapping from imported schedules")
    func preservedImportedByKeyDerivesFromSchedules() {
        let imported = Schedule(
            name: "Imported",
            days: [],
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(300),
            isEnabled: false,
            colorIndex: 4,
            type: .focus,
            ruleSetId: nil,
            importedCalendarEventKey: "event-1"
        )
        let mapping = AppStateScheduleCoordinator.preservedImportedByKey(from: [imported])

        #expect(mapping.count == 1)
        #expect(mapping["event-1"]?.id == imported.id)
        #expect(mapping["event-1"]?.isEnabled == false)
        #expect(mapping["event-1"]?.colorIndex == 4)
    }

    @Test("rebuildIfNeeded returns nil when rebuilt schedules are unchanged")
    func rebuildIfNeededNoChangeReturnsNil() {
        let now = Date()
        let local = Schedule(
            name: "Local",
            days: [Calendar.current.component(.weekday, from: now)],
            startTime: now.addingTimeInterval(-60),
            endTime: now.addingTimeInterval(60),
            type: .focus
        )

        let rebuilt = AppStateScheduleCoordinator.rebuildIfNeeded(
            currentSchedules: [local],
            events: [],
            shouldImportCalendarEvents: true,
            suppressedImportedCalendarEventKeys: [],
            focusTitleRules: [],
            breakTitleRules: [],
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()],
            weekStartsOnMonday: false
        )

        #expect(rebuilt == nil)
    }
}
