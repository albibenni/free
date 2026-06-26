import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct AppStateScheduleMutationCoordinatorTests {
    @Test("saveSchedule appends a new schedule through ScheduleEngine")
    func saveScheduleAddsEntry() async throws {
        let start = Date()
        let end = start.addingTimeInterval(3600)

        let updated = AppStateScheduleMutationCoordinator.saveSchedule(
            currentSchedules: [],
            name: "Focus",
            days: [2],
            date: nil,
            start: start,
            end: end,
            color: 1,
            type: .focus,
            ruleSet: nil,
            existingId: nil,
            modifyAllDays: true,
            initialDay: nil
        )

        #expect(updated.count == 1)
        #expect(updated.first?.name == "Focus")
        #expect(updated.first?.days == [2])
        #expect(updated.first?.type == .focus)
    }

    @Test("deleteSchedule suppresses imported calendar key when deleting imported schedule")
    func deleteScheduleSuppressesImportedKey() async throws {
        let imported = Schedule(
            name: "Imported",
            days: [],
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(900),
            isEnabled: false,
            colorIndex: 2,
            type: .focus,
            ruleSetId: nil,
            importedCalendarEventKey: "event-123"
        )

        let result = AppStateScheduleMutationCoordinator.deleteSchedule(
            currentSchedules: [imported],
            id: imported.id,
            modifyAllDays: true,
            initialDay: nil,
            suppressedImportedCalendarEventKeys: []
        )

        #expect(result.didMutateSchedules)
        #expect(result.schedules.isEmpty)
        #expect(result.didPersistSuppressedImportedKeys)
        #expect(result.suppressedImportedCalendarEventKeys.contains("event-123"))
    }

    @Test("deleteSchedule returns no mutation when id is missing")
    func deleteScheduleMissingIdIsNoop() async throws {
        let existing = Schedule(
            name: "Local",
            days: [2],
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            type: .focus
        )

        let result = AppStateScheduleMutationCoordinator.deleteSchedule(
            currentSchedules: [existing],
            id: UUID(),
            modifyAllDays: true,
            initialDay: nil,
            suppressedImportedCalendarEventKeys: []
        )

        #expect(!result.didMutateSchedules)
        #expect(result.schedules.count == 1)
        #expect(!result.didPersistSuppressedImportedKeys)
        #expect(result.suppressedImportedCalendarEventKeys.isEmpty)
    }
}
