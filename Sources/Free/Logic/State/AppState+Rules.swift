import Foundation

extension AppState {
    private func applyRulesUpdate(ruleSets newRuleSets: [RuleSet], activeRuleSetId newActiveRuleSetId: UUID?) {
        if ruleSets != newRuleSets {
            ruleSets = newRuleSets
        }
        if activeRuleSetId != newActiveRuleSetId {
            activeRuleSetId = newActiveRuleSetId
        }
    }

    private func mutateRule(_ rule: String, setId: UUID, mutation: AppStateLogicFacade.RuleMutation) {
        applyRulesUpdate(
            ruleSets: logicFacade.mutateRule(
                rule,
                setId: setId,
                currentRuleSets: ruleSets,
                isStrictActive: isStrictActive,
                mutation: mutation
            ),
            activeRuleSetId: activeRuleSetId
        )
    }

    func addRule(_ rule: String, to setId: UUID) {
        mutateRule(rule, setId: setId, mutation: .add)
    }

    func addSpecificRule(_ rule: String, to setId: UUID) {
        mutateRule(rule, setId: setId, mutation: .addSpecific)
    }

    func removeRule(_ rule: String, from setId: UUID) {
        mutateRule(rule, setId: setId, mutation: .remove)
    }

    func deleteSet(id: UUID) {
        let result = logicFacade.deleteRuleSet(
            id: id,
            currentRuleSets: ruleSets,
            currentActiveRuleSetId: activeRuleSetId,
            isStrictActive: isStrictActive
        )
        applyRulesUpdate(ruleSets: result.ruleSets, activeRuleSetId: result.activeRuleSetId)
    }

    @discardableResult
    func createRuleSet(name: String, makeActive: Bool = false) -> RuleSet {
        let result = logicFacade.createRuleSet(
            name: name,
            makeActive: makeActive,
            currentRuleSets: ruleSets,
            currentActiveRuleSetId: activeRuleSetId
        )
        applyRulesUpdate(ruleSets: result.ruleSets, activeRuleSetId: result.activeRuleSetId)
        return result.created
    }

    func selectActiveRuleSet(_ id: UUID) {
        applyRulesUpdate(
            ruleSets: ruleSets,
            activeRuleSetId: logicFacade.selectActiveRuleSet(
                id,
                currentRuleSets: ruleSets,
                currentActiveRuleSetId: activeRuleSetId,
                isStrictActive: isStrictActive
            )
        )
    }
}
