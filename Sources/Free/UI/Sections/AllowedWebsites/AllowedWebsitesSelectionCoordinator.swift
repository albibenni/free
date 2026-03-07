import Foundation

enum AllowedWebsitesSelectionCoordinator {
    static func resolvedRuleSetId(
        _ id: UUID?,
        ruleSets: [RuleSet],
        activeRuleSetId: UUID?
    ) -> UUID? {
        if let id, ruleSets.contains(where: { $0.id == id }) {
            return id
        }
        if let activeId = activeRuleSetId,
           ruleSets.contains(where: { $0.id == activeId })
        {
            return activeId
        }
        return ruleSets.first?.id
    }

    static func selectedRules(
        indexes: IndexSet,
        visibleRules: [String]
    ) -> [String] {
        indexes
            .filter { $0 >= 0 && $0 < visibleRules.count }
            .map { visibleRules[$0] }
    }

    static func selectedIndexes(
        preserving previouslySelectedRules: Set<String>,
        in visibleRules: [String]
    ) -> IndexSet {
        IndexSet(
            visibleRules.enumerated().compactMap { index, rule in
                previouslySelectedRules.contains(rule) ? index : nil
            }
        )
    }

    static func canRemoveSelection(
        selectedIndexes: IndexSet,
        visibleRulesCount: Int
    ) -> Bool {
        selectedIndexes.contains { $0 >= 0 && $0 < visibleRulesCount }
    }
}
