import Foundation

struct AppStateDependencies {
    let settingsStore: SettingsStore
    let calendarProvider: any CalendarProvider
    let timerCoordinator: AppStateTimerCoordinator
    let launchAtLoginService: LaunchAtLoginService
}

enum AppStateDependencyFactory {
    static func make(
        defaults: UserDefaults,
        injectedCalendar: (any CalendarProvider)?,
        timerScheduler: any RepeatingTimerScheduling,
        launchAtLoginManager: any LaunchAtLoginManaging,
        canPromptForLaunchAtLogin: @escaping () -> Bool,
        isTesting: Bool
    ) -> AppStateDependencies {
        let settingsStore = SettingsStore(defaults: defaults)
        let calendarProvider =
            injectedCalendar
            ?? (isTesting ? MockCalendarManager() : RealCalendarManager(nowProvider: { Date() }))
        let timerCoordinator = AppStateTimerCoordinator(timerScheduler: timerScheduler)
        let launchAtLoginService = LaunchAtLoginService(
            launchAtLoginManager: launchAtLoginManager,
            settingsStore: settingsStore,
            canPromptForLaunchAtLogin: canPromptForLaunchAtLogin
        )

        return AppStateDependencies(
            settingsStore: settingsStore,
            calendarProvider: calendarProvider,
            timerCoordinator: timerCoordinator,
            launchAtLoginService: launchAtLoginService
        )
    }
}
