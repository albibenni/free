import Foundation

enum RulesSheetActionsCoordinator {
    static func selectedRuleSet(id: UUID?, ruleSets: [RuleSet]) -> RuleSet? {
        guard let id else { return nil }
        return ruleSets.first(where: { $0.id == id })
    }

    static func fallbackSelectedSetId(
        currentSelectedId: UUID?,
        currentPrimaryRuleSetId: UUID?,
        ruleSets: [RuleSet]
    ) -> UUID? {
        let current = selectedRuleSet(id: currentSelectedId, ruleSets: ruleSets)
        return currentSelectedId == nil || current == nil
            ? (currentPrimaryRuleSetId ?? ruleSets.first?.id)
            : currentSelectedId
    }

    static func selectedSetIdAfterRowTap(
        tappedId: UUID,
        isBlocking: Bool,
        currentSelectedId: UUID?
    ) -> UUID? {
        guard !isBlocking else { return currentSelectedId }
        return tappedId
    }

    static func selectedSetIdAfterDelete(
        deletedId: UUID,
        currentSelectedId: UUID?,
        remainingRuleSets: [RuleSet]
    ) -> UUID? {
        currentSelectedId == deletedId ? remainingRuleSets.first?.id : currentSelectedId
    }

    static func toggledSuggestions(_ isExpanded: Bool) -> Bool {
        !isExpanded
    }
}
