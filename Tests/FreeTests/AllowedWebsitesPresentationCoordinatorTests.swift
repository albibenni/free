import Foundation
import Testing

@testable import FreeLogic

struct AllowedWebsitesPresentationCoordinatorTests {
    @Test("Presentation coordinator derives visible rules and list height")
    func visibleRulesAndListHeight() {
        let a = RuleSet(id: UUID(), name: "A", urls: ["a.com"])
        let b = RuleSet(id: UUID(), name: "B", urls: ["b.com", "c.com"])

        #expect(
            AllowedWebsitesPresentationCoordinator.visibleRules(
                selectedRuleSetId: b.id,
                ruleSets: [a, b]
            ) == ["b.com", "c.com"]
        )
        #expect(
            AllowedWebsitesPresentationCoordinator.visibleRules(
                selectedRuleSetId: UUID(),
                ruleSets: [a, b]
            ).isEmpty
        )

        #expect(AllowedWebsitesPresentationCoordinator.ruleSetListHeight(ruleSetCount: 0) == 38)
        #expect(AllowedWebsitesPresentationCoordinator.ruleSetListHeight(ruleSetCount: 2) == 76)
        #expect(AllowedWebsitesPresentationCoordinator.ruleSetListHeight(ruleSetCount: 99) == 150)

        let rows = AllowedWebsitesPresentationCoordinator.ruleSetRows(
            selectedRuleSetId: b.id,
            ruleSets: [a, b]
        )
        #expect(rows.count == 2)
        #expect(rows[0].id == a.id)
        #expect(rows[0].title == "A")
        #expect(rows[0].isSelected == false)
        #expect(rows[1].id == b.id)
        #expect(rows[1].title == "B")
        #expect(rows[1].isSelected == true)
    }

    @Test("Presentation coordinator computes control state flags")
    func controlState() {
        let editable = AllowedWebsitesPresentationCoordinator.controlState(
            selectedRuleSetId: UUID(),
            isStrictActive: false,
            selectedIndexes: IndexSet([1]),
            visibleRulesCount: 3,
            ruleSetCount: 2
        )
        #expect(editable.canEdit)
        #expect(editable.canRemove)
        #expect(editable.canCreateList)
        #expect(editable.canDeleteList)

        let strict = AllowedWebsitesPresentationCoordinator.controlState(
            selectedRuleSetId: UUID(),
            isStrictActive: true,
            selectedIndexes: IndexSet([1]),
            visibleRulesCount: 3,
            ruleSetCount: 2
        )
        #expect(strict.canEdit)
        #expect(strict.canRemove)
        #expect(!strict.canCreateList)
        #expect(!strict.canDeleteList)

        let noSelection = AllowedWebsitesPresentationCoordinator.controlState(
            selectedRuleSetId: nil,
            isStrictActive: false,
            selectedIndexes: IndexSet([0]),
            visibleRulesCount: 1,
            ruleSetCount: 1
        )
        #expect(!noSelection.canEdit)
        #expect(!noSelection.canRemove)
        #expect(noSelection.canCreateList)
        #expect(!noSelection.canDeleteList)
    }

    @Test("Presentation coordinator preserves selection across rules-content reload")
    func rulesContentState() {
        let selectedId = UUID()
        let set = RuleSet(
            id: selectedId,
            name: "A",
            urls: ["a.com", "c.com"]
        )

        let state = AllowedWebsitesPresentationCoordinator.rulesContentState(
            selectedRuleSetId: selectedId,
            ruleSets: [set],
            previousVisibleRules: ["a.com", "b.com", "c.com"],
            previousSelection: IndexSet([0, 1, 2])
        )

        #expect(state.visibleRules == ["a.com", "c.com"])
        #expect(state.preservedSelection == IndexSet([0, 1]))
        #expect(!state.showsEmptyState)

        let emptyState = AllowedWebsitesPresentationCoordinator.rulesContentState(
            selectedRuleSetId: UUID(),
            ruleSets: [set],
            previousVisibleRules: ["a.com"],
            previousSelection: IndexSet([0])
        )
        #expect(emptyState.visibleRules.isEmpty)
        #expect(emptyState.preservedSelection.isEmpty)
        #expect(emptyState.showsEmptyState)
    }
}
