import Combine
import Foundation

enum AppStatePersistenceCoordinator {
    struct Bindings {
        let isBlocking: AnyPublisher<Bool, Never>
        let isStrict: AnyPublisher<Bool, Never>
        let weekStartsOnMonday: AnyPublisher<Bool, Never>
        let accentColorIndex: AnyPublisher<Int, Never>
        let appearanceMode: AnyPublisher<AppearanceMode, Never>
        let cursorFluidAnimationEnabled: AnyPublisher<Bool, Never>
        let calendarIntegrationEnabled: AnyPublisher<Bool, Never>
        let calendarImportsBlockTime: AnyPublisher<Bool, Never>
        let calendarImportFocusTitleRules: AnyPublisher<[String], Never>
        let calendarImportBreakTitleRules: AnyPublisher<[String], Never>
        let calendarImportedScheduleRuleSetId: AnyPublisher<UUID?, Never>
        let blockNewTabs: AnyPublisher<Bool, Never>
        let blockDeveloperHosts: AnyPublisher<Bool, Never>
        let blockLocalNetworkHosts: AnyPublisher<Bool, Never>
        let allowSearchEngineWebsites: AnyPublisher<Bool, Never>
        let allowAIProviderWebsites: AnyPublisher<Bool, Never>
        let ruleSets: AnyPublisher<[RuleSet], Never>
        let activeRuleSetId: AnyPublisher<UUID?, Never>
        let pomodoroFocusDuration: AnyPublisher<Double, Never>
        let pomodoroBreakDuration: AnyPublisher<Double, Never>
    }

    static func persistSchedulesSynchronously(
        _ schedules: [Schedule],
        settingsStore: SettingsStore
    ) {
        settingsStore.saveSchedules(schedules)
    }

    static func bind(
        bindings: Bindings,
        settingsStore: SettingsStore
    ) -> Set<AnyCancellable> {
        var cancellables = Set<AnyCancellable>()

        bindings.isBlocking
            .dropFirst()
            .sink { settingsStore.setIsBlocking($0) }
            .store(in: &cancellables)

        bindings.isStrict
            .dropFirst()
            .sink { settingsStore.setIsStrict($0) }
            .store(in: &cancellables)

        bindings.weekStartsOnMonday
            .dropFirst()
            .sink { settingsStore.setWeekStartsOnMonday($0) }
            .store(in: &cancellables)

        bindings.accentColorIndex
            .dropFirst()
            .sink { settingsStore.setAccentColorIndex($0) }
            .store(in: &cancellables)

        bindings.appearanceMode
            .dropFirst()
            .sink { settingsStore.setAppearanceModeRawValue($0.rawValue) }
            .store(in: &cancellables)

        bindings.cursorFluidAnimationEnabled
            .dropFirst()
            .sink { settingsStore.setCursorFluidAnimationEnabled($0) }
            .store(in: &cancellables)

        bindings.calendarIntegrationEnabled
            .dropFirst()
            .sink { settingsStore.setCalendarIntegrationEnabled($0) }
            .store(in: &cancellables)

        bindings.calendarImportsBlockTime
            .dropFirst()
            .sink { settingsStore.setCalendarImportsBlockTime($0) }
            .store(in: &cancellables)

        bindings.calendarImportFocusTitleRules
            .dropFirst()
            .sink { settingsStore.setCalendarImportFocusTitleRules($0) }
            .store(in: &cancellables)

        bindings.calendarImportBreakTitleRules
            .dropFirst()
            .sink { settingsStore.setCalendarImportBreakTitleRules($0) }
            .store(in: &cancellables)

        bindings.calendarImportedScheduleRuleSetId
            .dropFirst()
            .sink { settingsStore.setCalendarImportedScheduleRuleSetId($0) }
            .store(in: &cancellables)

        bindings.blockNewTabs
            .dropFirst()
            .sink { settingsStore.setBlockNewTabs($0) }
            .store(in: &cancellables)

        bindings.blockDeveloperHosts
            .dropFirst()
            .sink { settingsStore.setBlockDeveloperHosts($0) }
            .store(in: &cancellables)

        bindings.blockLocalNetworkHosts
            .dropFirst()
            .sink { settingsStore.setBlockLocalNetworkHosts($0) }
            .store(in: &cancellables)

        bindings.allowSearchEngineWebsites
            .dropFirst()
            .sink { settingsStore.setAllowSearchEngineWebsites($0) }
            .store(in: &cancellables)

        bindings.allowAIProviderWebsites
            .dropFirst()
            .sink { settingsStore.setAllowAIProviderWebsites($0) }
            .store(in: &cancellables)

        bindings.ruleSets
            .dropFirst()
            .sink { settingsStore.saveRuleSets($0) }
            .store(in: &cancellables)

        bindings.activeRuleSetId
            .dropFirst()
            .sink { settingsStore.setActiveRuleSetId($0) }
            .store(in: &cancellables)

        bindings.pomodoroFocusDuration
            .dropFirst()
            .sink { settingsStore.setPomodoroFocusDuration($0) }
            .store(in: &cancellables)

        bindings.pomodoroBreakDuration
            .dropFirst()
            .sink { settingsStore.setPomodoroBreakDuration($0) }
            .store(in: &cancellables)

        return cancellables
    }
}
