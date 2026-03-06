import Foundation

enum AppStatePropertyEffectsService {
    static func handleIsBlockingDidChange(appState: AppState) {
        if !appState.isBlocking { appState.cancelPause() }
    }

    static func handleCalendarIntegrationEnabledDidChange(appState: AppState) {
        if appState.calendarIntegrationEnabled { appState.calendarProvider.requestAccess() }
        appState.checkSchedules()
    }

    static func handleCalendarImportsBlockTimeDidChange(appState: AppState) {
        appState.checkSchedules()
    }

    static func handleSchedulesDidChange(appState: AppState) {
        AppStatePersistenceCoordinator.persistSchedulesSynchronously(
            appState.schedules,
            settingsStore: appState.settingsStore
        )
        appState.checkSchedules()
    }

    static func handlePomodoroFocusDurationDidChange(appState: AppState) {
        if appState.pomodoroStatus == .focus {
            appState.pomodoroRemaining = appState.pomodoroFocusDuration * 60
        }
    }

    static func handlePomodoroBreakDurationDidChange(appState: AppState) {
        if appState.pomodoroStatus == .breakTime {
            appState.pomodoroRemaining = appState.pomodoroBreakDuration * 60
        }
    }
}
