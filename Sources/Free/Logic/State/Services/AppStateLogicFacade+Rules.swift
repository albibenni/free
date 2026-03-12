import Foundation

extension AppStateLogicFacade {
    func mutateRule(
        _ rule: String,
        setId: UUID,
        currentRuleSets: [RuleSet],
        isStrictActive: Bool,
        mutation: RuleMutation
    ) -> [RuleSet] {
        AppStateRuleSetCoordinator.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: currentRuleSets,
            isStrictActive: isStrictActive,
            mutation: mutation
        )
    }

    func deleteRuleSet(
        id: UUID,
        currentRuleSets: [RuleSet],
        currentActiveRuleSetId: UUID?,
        isStrictActive: Bool
    ) -> AppStateRuleSetCoordinator.RuleSetSelectionResult {
        AppStateRuleSetCoordinator.deleteRuleSet(
            id: id,
            currentRuleSets: currentRuleSets,
            currentActiveRuleSetId: currentActiveRuleSetId,
            isStrictActive: isStrictActive
        )
    }

    func createRuleSet(
        name: String,
        makeActive: Bool,
        currentRuleSets: [RuleSet],
        currentActiveRuleSetId: UUID?
    ) -> AppStateRuleSetCoordinator.RuleSetCreationResult {
        AppStateRuleSetCoordinator.createRuleSet(
            name: name,
            makeActive: makeActive,
            currentRuleSets: currentRuleSets,
            currentActiveRuleSetId: currentActiveRuleSetId
        )
    }

    func selectActiveRuleSet(
        _ id: UUID,
        currentRuleSets: [RuleSet],
        currentActiveRuleSetId: UUID?,
        isStrictActive: Bool
    ) -> UUID? {
        AppStateRuleSetCoordinator.selectActiveRuleSet(
            id,
            currentRuleSets: currentRuleSets,
            currentActiveRuleSetId: currentActiveRuleSetId,
            isStrictActive: isStrictActive
        )
    }

    func makeRuleContext(
        ruleSets: [RuleSet],
        schedules: [Schedule],
        activeRuleSetId: UUID?,
        pomodoroRuleSetId: UUID?,
        isPomodoroFocus: Bool,
        isBlocking: Bool,
        wasStartedBySchedule: Bool,
        allowSearchEngineWebsites: Bool,
        allowAIProviderWebsites: Bool
    ) -> RuleContext {
        RuleContext(
            ruleSets: ruleSets,
            schedules: schedules,
            activeRuleSetId: activeRuleSetId,
            pomodoroRuleSetId: pomodoroRuleSetId,
            isPomodoroFocus: isPomodoroFocus,
            isBlocking: isBlocking,
            wasStartedBySchedule: wasStartedBySchedule,
            allowSearchEngineWebsites: allowSearchEngineWebsites,
            allowAIProviderWebsites: allowAIProviderWebsites
        )
    }

    func currentPrimaryRuleSetId(context: RuleContext) -> UUID? {
        AppStateReadModelCoordinator.currentPrimaryRuleSetId(context: context)
    }

    func currentPrimaryRuleSetName(context: RuleContext) -> String {
        AppStateReadModelCoordinator.currentPrimaryRuleSetName(context: context)
    }

    func allowedRules(context: RuleContext) -> [String] {
        AppStateReadModelCoordinator.allowedRules(context: context)
    }
}
