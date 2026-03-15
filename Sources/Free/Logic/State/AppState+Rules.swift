import Foundation

extension AppState {
    private func rulesMutationContext(ignoringStrictMode: Bool) -> AppStateRulesMutationService.Context {
        AppStateRulesMutationService.Context(
            ruleSets: ruleSets,
            activeRuleSetId: activeRuleSetId,
            isStrictActive: isStrictActive && !ignoringStrictMode
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

    func addRule(_ rule: String, to setId: UUID, ignoreStrictMode: Bool = false) {
        applyRulesMutationUpdate(
            AppStateRulesMutationService.mutateRule(
                logicFacade: logicFacade,
                context: rulesMutationContext(ignoringStrictMode: ignoreStrictMode),
                rule: rule,
                setId: setId,
                mutation: .add
            )
        )
    }

    func addSpecificRule(_ rule: String, to setId: UUID, ignoreStrictMode: Bool = false) {
        applyRulesMutationUpdate(
            AppStateRulesMutationService.mutateRule(
                logicFacade: logicFacade,
                context: rulesMutationContext(ignoringStrictMode: ignoreStrictMode),
                rule: rule,
                setId: setId,
                mutation: .addSpecific
            )
        )
    }

    func removeRule(_ rule: String, from setId: UUID, ignoreStrictMode: Bool = false) {
        applyRulesMutationUpdate(
            AppStateRulesMutationService.mutateRule(
                logicFacade: logicFacade,
                context: rulesMutationContext(ignoringStrictMode: ignoreStrictMode),
                rule: rule,
                setId: setId,
                mutation: .remove
            )
        )
    }

    func deleteSet(id: UUID, ignoreStrictMode: Bool = false) {
        applyRulesMutationUpdate(
            AppStateRulesMutationService.deleteSet(
                logicFacade: logicFacade,
                context: rulesMutationContext(ignoringStrictMode: ignoreStrictMode),
                id: id
            )
        )
    }

    @discardableResult
    func createRuleSet(
        name: String,
        makeActive: Bool = false,
        ignoreStrictMode: Bool = false
    ) -> RuleSet {
        let result = AppStateRulesMutationService.createRuleSet(
            logicFacade: logicFacade,
            context: rulesMutationContext(ignoringStrictMode: ignoreStrictMode),
            name: name,
            makeActive: makeActive
        )
        applyRulesMutationUpdate(result.update)
        return result.created
    }

    func selectActiveRuleSet(_ id: UUID, ignoreStrictMode: Bool = false) {
        applyRulesMutationUpdate(
            AppStateRulesMutationService.selectActiveRuleSet(
                logicFacade: logicFacade,
                context: rulesMutationContext(ignoringStrictMode: ignoreStrictMode),
                id: id
            )
        )
    }
}
