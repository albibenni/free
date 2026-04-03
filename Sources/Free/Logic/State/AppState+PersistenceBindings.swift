import Combine
import Foundation

extension AppState {
    var persistenceBindings: AppStatePersistenceCoordinator.Bindings {
        AppStatePersistenceCoordinator.Bindings(
            isBlocking: $isBlocking.eraseToAnyPublisher(),
            isStrict: $isStrict.eraseToAnyPublisher(),
            weekStartsOnMonday: $weekStartsOnMonday.eraseToAnyPublisher(),
            accentColorIndex: $accentColorIndex.eraseToAnyPublisher(),
            appearanceMode: $appearanceMode.eraseToAnyPublisher(),
            cursorFluidAnimationEnabled: $cursorFluidAnimationEnabled.eraseToAnyPublisher(),
            calendarIntegrationEnabled: $calendarIntegrationEnabled.eraseToAnyPublisher(),
            calendarImportFocusTitleRules: $calendarImportFocusTitleRules.eraseToAnyPublisher(),
            calendarImportBreakTitleRules: $calendarImportBreakTitleRules.eraseToAnyPublisher(),
            calendarImportedScheduleRuleSetId: $calendarImportedScheduleRuleSetId.eraseToAnyPublisher(),
            blockNewTabs: $blockNewTabs.eraseToAnyPublisher(),
            blockDeveloperHosts: $blockDeveloperHosts.eraseToAnyPublisher(),
            blockLocalNetworkHosts: $blockLocalNetworkHosts.eraseToAnyPublisher(),
            allowSearchEngineWebsites: $allowSearchEngineWebsites.eraseToAnyPublisher(),
            allowAIProviderWebsites: $allowAIProviderWebsites.eraseToAnyPublisher(),
            ruleSets: $ruleSets.eraseToAnyPublisher(),
            activeRuleSetId: $activeRuleSetId.eraseToAnyPublisher(),
            pomodoroFocusDuration: $pomodoroFocusDuration.eraseToAnyPublisher(),
            pomodoroBreakDuration: $pomodoroBreakDuration.eraseToAnyPublisher()
        )
    }
}
