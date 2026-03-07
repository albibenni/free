import Foundation

extension AppState {
    private var rulesMutationContext: AppStateRulesMutationService.Context {
        AppStateRulesMutationService.Context(
            ruleSets: ruleSets,
            activeRuleSetId: activeRuleSetId,
            isStrictActive: isStrictActive
        )
    }

    private func applyRulesMutationUpdate(_ update: AppStateRulesMutationService.Update) {
        if ruleSets != update.ruleSets {
            ruleSets = update.ruleSets
        }
        if activeRuleSetId != update.activeRuleSetId {
            activeRuleSetId = update.activeRuleSetId
        }
    }

    func addRule(_ rule: String, to setId: UUID) {
        applyRulesMutationUpdate(
            AppStateRulesMutationService.mutateRule(
                logicFacade: logicFacade,
                context: rulesMutationContext,
                rule: rule,
                setId: setId,
                mutation: .add
            )
        )
    }

    func addSpecificRule(_ rule: String, to setId: UUID) {
        applyRulesMutationUpdate(
            AppStateRulesMutationService.mutateRule(
                logicFacade: logicFacade,
                context: rulesMutationContext,
                rule: rule,
                setId: setId,
                mutation: .addSpecific
            )
        )
    }

    func removeRule(_ rule: String, from setId: UUID) {
        applyRulesMutationUpdate(
            AppStateRulesMutationService.mutateRule(
                logicFacade: logicFacade,
                context: rulesMutationContext,
                rule: rule,
                setId: setId,
                mutation: .remove
            )
        )
    }

    func deleteSet(id: UUID) {
        applyRulesMutationUpdate(
            AppStateRulesMutationService.deleteSet(
                logicFacade: logicFacade,
                context: rulesMutationContext,
                id: id
            )
        )
    }

    @discardableResult
    func createRuleSet(name: String, makeActive: Bool = false) -> RuleSet {
        let result = AppStateRulesMutationService.createRuleSet(
            logicFacade: logicFacade,
            context: rulesMutationContext,
            name: name,
            makeActive: makeActive
        )
        applyRulesMutationUpdate(result.update)
        return result.created
    }

    func selectActiveRuleSet(_ id: UUID) {
        applyRulesMutationUpdate(
            AppStateRulesMutationService.selectActiveRuleSet(
                logicFacade: logicFacade,
                context: rulesMutationContext,
                id: id
            )
        )
    }
}
