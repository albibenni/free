import Combine
import Foundation

enum AppStatePersistenceCoordinator {
    static func bind(
        appState: AppState,
        settingsStore: SettingsStore
    ) -> Set<AnyCancellable> {
        var cancellables = Set<AnyCancellable>()

        appState.$isBlocking
            .dropFirst()
            .sink { settingsStore.setIsBlocking($0) }
            .store(in: &cancellables)

        appState.$isUnblockable
            .dropFirst()
            .sink { settingsStore.setIsUnblockable($0) }
            .store(in: &cancellables)

        appState.$weekStartsOnMonday
            .dropFirst()
            .sink { settingsStore.setWeekStartsOnMonday($0) }
            .store(in: &cancellables)

        appState.$accentColorIndex
            .dropFirst()
            .sink { settingsStore.setAccentColorIndex($0) }
            .store(in: &cancellables)

        appState.$appearanceMode
            .dropFirst()
            .sink { settingsStore.setAppearanceModeRawValue($0.rawValue) }
            .store(in: &cancellables)

        appState.$calendarIntegrationEnabled
            .dropFirst()
            .sink { settingsStore.setCalendarIntegrationEnabled($0) }
            .store(in: &cancellables)

        appState.$calendarImportsBlockTime
            .dropFirst()
            .sink { settingsStore.setCalendarImportsBlockTime($0) }
            .store(in: &cancellables)

        appState.$blockNewTabs
            .dropFirst()
            .sink { settingsStore.setBlockNewTabs($0) }
            .store(in: &cancellables)

        appState.$blockDeveloperHosts
            .dropFirst()
            .sink { settingsStore.setBlockDeveloperHosts($0) }
            .store(in: &cancellables)

        appState.$blockLocalNetworkHosts
            .dropFirst()
            .sink { settingsStore.setBlockLocalNetworkHosts($0) }
            .store(in: &cancellables)

        appState.$ruleSets
            .dropFirst()
            .sink { settingsStore.saveRuleSets($0) }
            .store(in: &cancellables)

        appState.$activeRuleSetId
            .dropFirst()
            .sink { settingsStore.setActiveRuleSetId($0) }
            .store(in: &cancellables)

        appState.$pomodoroFocusDuration
            .dropFirst()
            .sink { settingsStore.setPomodoroFocusDuration($0) }
            .store(in: &cancellables)

        appState.$pomodoroBreakDuration
            .dropFirst()
            .sink { settingsStore.setPomodoroBreakDuration($0) }
            .store(in: &cancellables)

        return cancellables
    }
}
