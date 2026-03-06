import Foundation

enum AppStateRuleSetCoordinator {
    enum RuleMutation {
        case add
        case addSpecific
        case remove
    }

    struct RuleSetSelectionResult: Equatable {
        let ruleSets: [RuleSet]
        let activeRuleSetId: UUID?
    }

    struct RuleSetCreationResult: Equatable {
        let created: RuleSet
        let ruleSets: [RuleSet]
        let activeRuleSetId: UUID?
    }

    static func mutateRule(
        _ rule: String,
        setId: UUID,
        currentRuleSets: [RuleSet],
        isStrictActive: Bool,
        mutation: RuleMutation
    ) -> [RuleSet] {
        guard !isStrictActive else { return currentRuleSets }
        var ruleSets = currentRuleSets

        switch mutation {
        case .add:
            RuleSetService.addRule(rule, to: setId, in: &ruleSets)
        case .addSpecific:
            RuleSetService.addSpecificRule(rule, to: setId, in: &ruleSets)
        case .remove:
            RuleSetService.removeRule(rule, from: setId, in: &ruleSets)
        }

        return ruleSets
    }

    static func deleteRuleSet(
        id: UUID,
        currentRuleSets: [RuleSet],
        currentActiveRuleSetId: UUID?,
        isStrictActive: Bool
    ) -> RuleSetSelectionResult {
        var ruleSets = currentRuleSets
        var activeRuleSetId = currentActiveRuleSetId
        _ = RuleSetCoordinator.deleteRuleSet(
            id: id,
            in: &ruleSets,
            activeRuleSetId: &activeRuleSetId,
            isStrictActive: isStrictActive
        )
        return RuleSetSelectionResult(ruleSets: ruleSets, activeRuleSetId: activeRuleSetId)
    }

    static func createRuleSet(
        name: String,
        makeActive: Bool,
        currentRuleSets: [RuleSet],
        currentActiveRuleSetId: UUID?
    ) -> RuleSetCreationResult {
        var ruleSets = currentRuleSets
        var activeRuleSetId = currentActiveRuleSetId
        let created = RuleSetCoordinator.createRuleSet(
            name: name,
            makeActive: makeActive,
            in: &ruleSets,
            activeRuleSetId: &activeRuleSetId
        )

        return RuleSetCreationResult(
            created: created,
            ruleSets: ruleSets,
            activeRuleSetId: activeRuleSetId
        )
    }

    static func selectActiveRuleSet(
        _ id: UUID,
        currentRuleSets: [RuleSet],
        currentActiveRuleSetId: UUID?,
        isStrictActive: Bool
    ) -> UUID? {
        RuleSetCoordinator.selectActiveRuleSet(
            id,
            in: currentRuleSets,
            currentActiveRuleSetId: currentActiveRuleSetId,
            isStrictActive: isStrictActive
        )
    }
}
