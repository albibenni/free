import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct AppStateSessionCoordinatorTests {
    @Test("toggle updates blocking state and pauses active focus schedules")
    func toggleUpdatesBlockingAndPausedIds() async throws {
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        let focus = Schedule(
            name: "Focus",
            days: [today],
            startTime: now.addingTimeInterval(-600),
            endTime: now.addingTimeInterval(600),
            type: .focus
        )

        let initial = AppStateSessionCoordinator.SessionState(
            isBlocking: true,
            wasStartedBySchedule: true,
            manuallyPausedScheduleIds: []
        )
        let updated = AppStateSessionCoordinator.toggle(
            current: initial,
            isStrict: false,
            schedules: [focus]
        )

        #expect(!updated.isBlocking)
        #expect(!updated.wasStartedBySchedule)
        #expect(updated.manuallyPausedScheduleIds.contains(focus.id))
    }

    @Test("check starts schedule-driven blocking when active focus exists")
    func checkStartsScheduleBlocking() async throws {
        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        let focus = Schedule(
            name: "Focus",
            days: [today],
            startTime: now.addingTimeInterval(-300),
            endTime: now.addingTimeInterval(300),
            type: .focus
        )

        let initial = AppStateSessionCoordinator.SessionState(
            isBlocking: false,
            wasStartedBySchedule: false,
            manuallyPausedScheduleIds: []
        )

        let updated = AppStateSessionCoordinator.check(
            current: initial,
            schedules: [focus],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: false,
            isStrict: false,
            calendarEvents: []
        )

        #expect(updated.isBlocking)
        #expect(updated.wasStartedBySchedule)
    }

    @Test("legacy migration returns nil when source flag already persisted")
    func legacyMigrationNoopWhenPersisted() async throws {
        let current = AppStateSessionCoordinator.SessionState(
            isBlocking: true,
            wasStartedBySchedule: false,
            manuallyPausedScheduleIds: []
        )

        let result = AppStateSessionCoordinator.migrateLegacyBlockingSourceIfNeeded(
            hasPersistedWasStartedBySchedule: true,
            current: current,
            schedules: [],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: false,
            isStrict: false,
            calendarEvents: []
        )

        #expect(result == nil)
    }
}
