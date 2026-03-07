import Foundation

enum AppStateRulesMutationService {
    struct Context {
        let ruleSets: [RuleSet]
        let activeRuleSetId: UUID?
        let isStrictActive: Bool
    }

    struct Update {
        let ruleSets: [RuleSet]
        let activeRuleSetId: UUID?
    }

    static func mutateRule(
        logicFacade: AppStateLogicFacade,
        context: Context,
        rule: String,
        setId: UUID,
        mutation: AppStateLogicFacade.RuleMutation
    ) -> Update {
        Update(
            ruleSets: logicFacade.mutateRule(
                rule,
                setId: setId,
                currentRuleSets: context.ruleSets,
                isStrictActive: context.isStrictActive,
                mutation: mutation
            ),
            activeRuleSetId: context.activeRuleSetId
        )
    }

    static func deleteSet(
        logicFacade: AppStateLogicFacade,
        context: Context,
        id: UUID
    ) -> Update {
        let result = logicFacade.deleteRuleSet(
            id: id,
            currentRuleSets: context.ruleSets,
            currentActiveRuleSetId: context.activeRuleSetId,
            isStrictActive: context.isStrictActive
        )
        return Update(
            ruleSets: result.ruleSets,
            activeRuleSetId: result.activeRuleSetId
        )
    }

    static func createRuleSet(
        logicFacade: AppStateLogicFacade,
        context: Context,
        name: String,
        makeActive: Bool
    ) -> (created: RuleSet, update: Update) {
        let result = logicFacade.createRuleSet(
            name: name,
            makeActive: makeActive,
            currentRuleSets: context.ruleSets,
            currentActiveRuleSetId: context.activeRuleSetId
        )
        return (
            created: result.created,
            update: Update(
                ruleSets: result.ruleSets,
                activeRuleSetId: result.activeRuleSetId
            )
        )
    }

    static func selectActiveRuleSet(
        logicFacade: AppStateLogicFacade,
        context: Context,
        id: UUID
    ) -> Update {
        Update(
            ruleSets: context.ruleSets,
            activeRuleSetId: logicFacade.selectActiveRuleSet(
                id,
                currentRuleSets: context.ruleSets,
                currentActiveRuleSetId: context.activeRuleSetId,
                isStrictActive: context.isStrictActive
            )
        )
    }
}
