import Foundation

enum AllowedWebsitesRuleSetActionsCoordinator {
    static func canCreateRuleSet(isStrictActive: Bool) -> Bool {
        !isStrictActive
    }

    static func canDeleteRuleSet(
        isStrictActive: Bool,
        ruleSetCount: Int
    ) -> Bool {
        !isStrictActive && ruleSetCount > 1
    }

    static func selectedRuleSet(
        id: UUID?,
        ruleSets: [RuleSet]
    ) -> RuleSet? {
        guard let id else { return nil }
        return ruleSets.first(where: { $0.id == id })
    }

    static func selectedRuleSetAfterRowTap(
        tappedId: UUID,
        currentSelectedId: UUID?,
        isStrictActive: Bool
    ) -> UUID? {
        guard !isStrictActive else { return currentSelectedId }
        return tappedId
    }

    static func createRuleSet(
        appState: AppState,
        name: String
    ) -> RuleSet {
        appState.createRuleSet(name: name, makeActive: false)
    }

    static func deleteRuleSet(
        appState: AppState,
        id: UUID
    ) {
        appState.deleteSet(id: id)
    }
}
