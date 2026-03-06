import Foundation

enum AllowedWebsitesPresentationCoordinator {
    struct ControlState: Equatable {
        let canEdit: Bool
        let canRemove: Bool
        let canCreateList: Bool
        let canDeleteList: Bool
    }

    static func visibleRules(
        selectedRuleSetId: UUID?,
        ruleSets: [RuleSet]
    ) -> [String] {
        ruleSets.first(where: { $0.id == selectedRuleSetId })?.urls ?? []
    }

    static func ruleSetListHeight(
        ruleSetCount: Int
    ) -> CGFloat {
        let rowCount = max(ruleSetCount, 1)
        let desiredHeight = CGFloat(rowCount) * 38
        return min(max(desiredHeight, 38), 150)
    }

    static func controlState(
        selectedRuleSetId: UUID?,
        isStrictActive: Bool,
        selectedIndexes: IndexSet,
        visibleRulesCount: Int,
        ruleSetCount: Int
    ) -> ControlState {
        let canEdit = selectedRuleSetId != nil && !isStrictActive
        let canRemove = canEdit && AllowedWebsitesSelectionCoordinator.canRemoveSelection(
            selectedIndexes: selectedIndexes,
            visibleRulesCount: visibleRulesCount
        )
        return ControlState(
            canEdit: canEdit,
            canRemove: canRemove,
            canCreateList: !isStrictActive,
            canDeleteList: !isStrictActive && ruleSetCount > 1
        )
    }
}
