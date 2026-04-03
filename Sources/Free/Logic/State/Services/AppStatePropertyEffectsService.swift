import Foundation

enum AppStatePropertyEffectsService {
    static func handleIsBlockingDidChange(
        isBlocking: Bool,
        cancelPause: () -> Void
    ) {
        if !isBlocking { cancelPause() }
    }

    static func handleCalendarIntegrationEnabledDidChange(
        isEnabled: Bool,
        requestAccess: () -> Void,
        checkSchedules: () -> Void
    ) {
        if isEnabled { requestAccess() }
        checkSchedules()
    }

    static func handleSchedulesDidChange(
        schedules: [Schedule],
        settingsStore: SettingsStore,
        checkSchedules: () -> Void
    ) {
        AppStatePersistenceCoordinator.persistSchedulesSynchronously(
            schedules,
            settingsStore: settingsStore
        )
        checkSchedules()
    }

    static func updatedPomodoroRemainingAfterFocusDurationDidChange(
        isFocusActive: Bool,
        focusDurationMinutes: Double,
        currentRemaining: TimeInterval
    ) -> TimeInterval {
        guard isFocusActive else { return currentRemaining }
        return focusDurationMinutes * 60
    }

    static func updatedPomodoroRemainingAfterBreakDurationDidChange(
        isBreakActive: Bool,
        breakDurationMinutes: Double,
        currentRemaining: TimeInterval
    ) -> TimeInterval {
        guard isBreakActive else { return currentRemaining }
        return breakDurationMinutes * 60
    }
}
