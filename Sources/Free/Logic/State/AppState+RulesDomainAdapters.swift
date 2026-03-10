import Foundation

extension AppState {
    var ruleContext: AppStateLogicFacade.RuleContext {
        logicFacade.makeRuleContext(
            ruleSets: rulesDomainState.ruleSets,
            schedules: scheduleDomainState.schedules,
            activeRuleSetId: rulesDomainState.activeRuleSetId,
            pomodoroRuleSetId: pomodoroDomainState.ruleSetId,
            isPomodoroFocus: pomodoroDomainState.status == .focus,
            isBlocking: sessionDomainState.isBlocking,
            wasStartedBySchedule: sessionDomainState.wasStartedBySchedule,
            allowSearchEngineWebsites: settingsDomainState.allowSearchEngineWebsites,
            allowAIProviderWebsites: settingsDomainState.allowAIProviderWebsites
        )
    }

    var rulesDomainState: AppRulesDomainState {
        AppRulesDomainState(ruleSets: ruleSets, activeRuleSetId: activeRuleSetId)
    }

    func applyRulesDomainState(_ state: AppRulesDomainState) {
        if ruleSets != state.ruleSets { ruleSets = state.ruleSets }
        if activeRuleSetId != state.activeRuleSetId { activeRuleSetId = state.activeRuleSetId }
    }
}
