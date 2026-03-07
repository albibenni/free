import Foundation
import Testing

@testable import FreeLogic

struct BlockingSessionServiceTests {
    private func activeFocusSchedule() -> Schedule {
        let now = Date()
        let day = Calendar.current.component(.weekday, from: now)
        return Schedule(
            name: "Focus",
            days: [day],
            startTime: now.addingTimeInterval(-300),
            endTime: now.addingTimeInterval(300),
            type: .focus
        )
    }

    @Test("toggleBlocking keeps state unchanged when strict mode is active")
    func toggleBlockingStrictModeNoop() {
        let initialPaused: Set<UUID> = [UUID()]
        let result = BlockingSessionService.toggleBlocking(
            isBlocking: true,
            isUnblockable: true,
            schedules: [],
            manuallyPausedScheduleIds: initialPaused,
            wasStartedBySchedule: true
        )

        #expect(result.isBlocking)
        #expect(result.wasStartedBySchedule)
        #expect(result.manuallyPausedScheduleIds == initialPaused)
    }

    @Test("toggleBlocking adds active focus schedules to paused ids when turning off")
    func toggleBlockingAddsActiveFocusIds() {
        let schedule = activeFocusSchedule()
        let result = BlockingSessionService.toggleBlocking(
            isBlocking: true,
            isUnblockable: false,
            schedules: [schedule],
            manuallyPausedScheduleIds: [],
            wasStartedBySchedule: true
        )

        #expect(!result.isBlocking)
        #expect(!result.wasStartedBySchedule)
        #expect(result.manuallyPausedScheduleIds.contains(schedule.id))
    }

    @Test("scheduleTransition starts schedule-driven blocking when needed")
    func scheduleTransitionStartsAutomaticBlocking() {
        let result = BlockingSessionService.scheduleTransition(
            isBlocking: false,
            wasStartedBySchedule: false,
            shouldBeBlocking: true
        )

        #expect(result.isBlocking)
        #expect(result.wasStartedBySchedule)
    }

    @Test("scheduleTransition stops only schedule-driven blocking")
    func scheduleTransitionStopsOnlyScheduleDrivenBlocking() {
        let stops = BlockingSessionService.scheduleTransition(
            isBlocking: true,
            wasStartedBySchedule: true,
            shouldBeBlocking: false
        )
        let keeps = BlockingSessionService.scheduleTransition(
            isBlocking: true,
            wasStartedBySchedule: false,
            shouldBeBlocking: false
        )

        #expect(!stops.isBlocking)
        #expect(!stops.wasStartedBySchedule)
        #expect(keeps.isBlocking)
        #expect(!keeps.wasStartedBySchedule)
    }
}
