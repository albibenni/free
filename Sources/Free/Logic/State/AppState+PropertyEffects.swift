import Foundation

extension AppState {
    func handleIsBlockingDidChange() {
        if !isBlocking { cancelPause() }
    }

    func handleCalendarIntegrationEnabledDidChange() {
        if calendarIntegrationEnabled { calendarProvider.requestAccess() }
        checkSchedules()
    }

    func handleCalendarImportsBlockTimeDidChange() {
        checkSchedules()
    }

    func handleSchedulesDidChange() {
        AppStatePersistenceCoordinator.persistSchedulesSynchronously(
            schedules,
            settingsStore: settingsStore
        )
        checkSchedules()
    }

    func handlePomodoroFocusDurationDidChange() {
        if pomodoroStatus == .focus { pomodoroRemaining = pomodoroFocusDuration * 60 }
    }

    func handlePomodoroBreakDurationDidChange() {
        if pomodoroStatus == .breakTime { pomodoroRemaining = pomodoroBreakDuration * 60 }
    }
}
