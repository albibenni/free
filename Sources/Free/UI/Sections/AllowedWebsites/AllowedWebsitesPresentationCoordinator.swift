import Foundation

enum AllowedWebsitesPresentationCoordinator {
    struct RuleSetRow: Equatable {
        let id: UUID
        let title: String
        let isSelected: Bool
    }

    struct ControlState: Equatable {
        let canEdit: Bool
        let canRemove: Bool
        let canCreateList: Bool
        let canDeleteList: Bool
    }

    struct RulesContentState: Equatable {
        let visibleRules: [String]
        let preservedSelection: IndexSet

        var showsEmptyState: Bool {
            visibleRules.isEmpty
        }
    }

    static func visibleRules(
        selectedRuleSetId: UUID?,
        ruleSets: [RuleSet]
    ) -> [String] {
        ruleSets.first(where: { $0.id == selectedRuleSetId })?.urls ?? []
    }

    static func rulesContentState(
        selectedRuleSetId: UUID?,
        ruleSets: [RuleSet],
        previousVisibleRules: [String],
        previousSelection: IndexSet
    ) -> RulesContentState {
        let nextVisibleRules = visibleRules(
            selectedRuleSetId: selectedRuleSetId,
            ruleSets: ruleSets
        )
        let previouslySelectedRules = Set(AllowedWebsitesSelectionCoordinator.selectedRules(
            indexes: previousSelection,
            visibleRules: previousVisibleRules
        ))
        let preservedSelection = AllowedWebsitesSelectionCoordinator.selectedIndexes(
            preserving: previouslySelectedRules,
            in: nextVisibleRules
        )
        return RulesContentState(
            visibleRules: nextVisibleRules,
            preservedSelection: preservedSelection
        )
    }

    static func ruleSetRows(
        selectedRuleSetId: UUID?,
        ruleSets: [RuleSet]
    ) -> [RuleSetRow] {
        ruleSets.map { set in
            RuleSetRow(
                id: set.id,
                title: set.name,
                isSelected: selectedRuleSetId == set.id
            )
        }
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
