import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct AppStateSchedulesMutationServiceTests {
    private func makeSchedule(
        name: String = "Focus",
        day: Int = 2,
        importedKey: String? = nil
    ) -> Schedule {
        Schedule(
            name: name,
            days: [day],
            date: importedKey == nil ? nil : Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            isEnabled: true,
            colorIndex: 1,
            type: .focus,
            importedCalendarEventKey: importedKey
        )
    }

    @Test("deleteSchedule returns nil when no mutation occurs")
    func deleteScheduleNoMutationReturnsNil() async throws {
        let existing = makeSchedule()
        let update = AppStateSchedulesMutationService.deleteSchedule(
            logicFacade: .live,
            context: .init(
                schedules: [existing],
                suppressedImportedCalendarEventKeys: []
            ),
            id: UUID(),
            modifyAllDays: true,
            initialDay: nil
        )

        #expect(update == nil)
    }

    @Test("deleteSchedule returns update and persists suppressed imported key when needed")
    func deleteScheduleMutationUpdate() async throws {
        let imported = makeSchedule(importedKey: "event-123")
        let update = AppStateSchedulesMutationService.deleteSchedule(
            logicFacade: .live,
            context: .init(
                schedules: [imported],
                suppressedImportedCalendarEventKeys: []
            ),
            id: imported.id,
            modifyAllDays: true,
            initialDay: nil
        )

        #expect(update != nil)
        #expect(update?.schedules.isEmpty == true)
        #expect(update?.suppressedImportedCalendarEventKeys.contains("event-123") == true)
        #expect(update?.shouldPersistSuppressedKeys == true)
    }

    @Test("saveSchedule keeps suppressed keys unchanged and does not persist key set")
    func saveScheduleUpdatePayload() async throws {
        let initial = makeSchedule(name: "Existing")
        let suppressed: Set<String> = ["event-1"]
        let start = Date()
        let end = start.addingTimeInterval(2700)

        let update = AppStateSchedulesMutationService.saveSchedule(
            logicFacade: .live,
            context: .init(
                schedules: [initial],
                suppressedImportedCalendarEventKeys: suppressed
            ),
            name: "New",
            days: [2, 4],
            date: nil,
            start: start,
            end: end,
            color: 2,
            type: .unfocus,
            ruleSet: nil,
            existingId: nil,
            modifyAllDays: true,
            initialDay: nil
        )

        #expect(update.schedules.count == 2)
        #expect(update.schedules.contains(where: { $0.name == "New" && $0.type == .unfocus }))
        #expect(update.suppressedImportedCalendarEventKeys == suppressed)
        #expect(update.shouldPersistSuppressedKeys == false)
    }

    @Test("updateScheduleOccurrence keeps suppressed keys and updates schedule timing/day")
    func updateScheduleOccurrencePayload() async throws {
        let calendar = Calendar.current
        let originalStart = calendar.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        let originalEnd = calendar.date(from: DateComponents(hour: 10, minute: 0)) ?? Date()
        let existing = Schedule(
            name: "Recurring",
            days: [2],
            startTime: originalStart,
            endTime: originalEnd,
            isEnabled: true,
            colorIndex: 0,
            type: .focus
        )

        let start = calendar.date(from: DateComponents(hour: 11, minute: 15)) ?? originalStart
        let end = calendar.date(from: DateComponents(hour: 12, minute: 0)) ?? originalEnd
        let suppressed: Set<String> = ["event-2"]

        let update = AppStateSchedulesMutationService.updateScheduleOccurrence(
            logicFacade: .live,
            context: .init(
                schedules: [existing],
                suppressedImportedCalendarEventKeys: suppressed
            ),
            id: existing.id,
            originalDay: 2,
            targetDay: 4,
            targetDate: nil,
            start: start,
            end: end
        )

        #expect(update.schedules.count == 1)
        #expect(update.schedules.first?.days == [4])
        #expect(update.schedules.first?.startTime == start)
        #expect(update.schedules.first?.endTime == end)
        #expect(update.suppressedImportedCalendarEventKeys == suppressed)
        #expect(update.shouldPersistSuppressedKeys == false)
    }
}
