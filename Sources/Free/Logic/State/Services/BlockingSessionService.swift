import Foundation

struct BlockingSessionService {
    struct ToggleResult: Equatable {
        let isBlocking: Bool
        let wasStartedBySchedule: Bool
        let manuallyPausedScheduleIds: Set<UUID>
    }

    struct ScheduleTransitionResult: Equatable {
        let isBlocking: Bool
        let wasStartedBySchedule: Bool
    }

    static func toggleBlocking(
        isBlocking: Bool,
        isStrict: Bool,
        schedules: [Schedule],
        manuallyPausedScheduleIds: Set<UUID>,
        wasStartedBySchedule: Bool
    ) -> ToggleResult {
        guard !(isBlocking && isStrict) else {
            return ToggleResult(
                isBlocking: isBlocking,
                wasStartedBySchedule: wasStartedBySchedule,
                manuallyPausedScheduleIds: manuallyPausedScheduleIds
            )
        }

        var updatedPausedIds = manuallyPausedScheduleIds
        if isBlocking {
            let activeFocusIds = schedules
                .filter { $0.isActive() && $0.type == .focus }
                .map(\.id)
            updatedPausedIds.formUnion(activeFocusIds)
        } else {
            updatedPausedIds.removeAll()
        }

        return ToggleResult(
            isBlocking: !isBlocking,
            wasStartedBySchedule: false,
            manuallyPausedScheduleIds: updatedPausedIds
        )
    }

    static func scheduleTransition(
        isBlocking: Bool,
        wasStartedBySchedule: Bool,
        shouldBeBlocking: Bool
    ) -> ScheduleTransitionResult {
        if shouldBeBlocking && !isBlocking {
            return ScheduleTransitionResult(isBlocking: true, wasStartedBySchedule: true)
        }

        if !shouldBeBlocking && isBlocking && wasStartedBySchedule {
            return ScheduleTransitionResult(isBlocking: false, wasStartedBySchedule: false)
        }

        return ScheduleTransitionResult(
            isBlocking: isBlocking,
            wasStartedBySchedule: wasStartedBySchedule
        )
    }
}
