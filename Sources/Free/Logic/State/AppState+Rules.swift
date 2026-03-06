import Foundation

extension AppState {
    func addRule(_ rule: String, to setId: UUID) {
        ruleSets = logicFacade.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: ruleSets,
            isStrictActive: isStrictActive,
            mutation: .add
        )
    }

    func addSpecificRule(_ rule: String, to setId: UUID) {
        ruleSets = logicFacade.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: ruleSets,
            isStrictActive: isStrictActive,
            mutation: .addSpecific
        )
    }

    func removeRule(_ rule: String, from setId: UUID) {
        ruleSets = logicFacade.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: ruleSets,
            isStrictActive: isStrictActive,
            mutation: .remove
        )
    }

    func deleteSet(id: UUID) {
        let result = logicFacade.deleteRuleSet(
            id: id,
            currentRuleSets: ruleSets,
            currentActiveRuleSetId: activeRuleSetId,
            isStrictActive: isStrictActive
        )
        ruleSets = result.ruleSets
        activeRuleSetId = result.activeRuleSetId
    }

    @discardableResult
    func createRuleSet(name: String, makeActive: Bool = false) -> RuleSet {
        let result = logicFacade.createRuleSet(
            name: name,
            makeActive: makeActive,
            currentRuleSets: ruleSets,
            currentActiveRuleSetId: activeRuleSetId
        )
        ruleSets = result.ruleSets
        activeRuleSetId = result.activeRuleSetId
        return result.created
    }

    func selectActiveRuleSet(_ id: UUID) {
        activeRuleSetId = logicFacade.selectActiveRuleSet(
            id,
            currentRuleSets: ruleSets,
            currentActiveRuleSetId: activeRuleSetId,
            isStrictActive: isStrictActive
        )
    }
}
