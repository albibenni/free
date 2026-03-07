import AppKit
import Foundation
import Testing

@testable import FreeLogic

struct AllowedWebsitesCoordinatorsTests {
    @Test("Selection coordinator resolves selected, active, and fallback rule set ids")
    func selectionCoordinatorResolveRuleSetId() {
        let a = RuleSet(id: UUID(), name: "A", urls: [])
        let b = RuleSet(id: UUID(), name: "B", urls: [])
        let ruleSets = [a, b]

        #expect(
            AllowedWebsitesSelectionCoordinator.resolvedRuleSetId(
                a.id,
                ruleSets: ruleSets,
                activeRuleSetId: b.id
            ) == a.id
        )
        #expect(
            AllowedWebsitesSelectionCoordinator.resolvedRuleSetId(
                UUID(),
                ruleSets: ruleSets,
                activeRuleSetId: b.id
            ) == b.id
        )
        #expect(
            AllowedWebsitesSelectionCoordinator.resolvedRuleSetId(
                nil,
                ruleSets: ruleSets,
                activeRuleSetId: UUID()
            ) == a.id
        )
        #expect(
            AllowedWebsitesSelectionCoordinator.resolvedRuleSetId(
                nil,
                ruleSets: [],
                activeRuleSetId: nil
            ) == nil
        )
    }

    @Test("Selection coordinator maps selected rows and preserves selection by rule")
    func selectionCoordinatorSelectionMapping() {
        let rules = ["a.com", "b.com", "c.com"]
        let selected = AllowedWebsitesSelectionCoordinator.selectedRules(
            indexes: IndexSet([0, 2, 5]),
            visibleRules: rules
        )
        #expect(selected == ["a.com", "c.com"])

        let reselected = AllowedWebsitesSelectionCoordinator.selectedIndexes(
            preserving: ["c.com", "missing"],
            in: ["c.com", "z.com"]
        )
        #expect(reselected == IndexSet([0]))

        #expect(
            AllowedWebsitesSelectionCoordinator.canRemoveSelection(
                selectedIndexes: IndexSet([4]),
                visibleRulesCount: 3
            ) == false
        )
        #expect(
            AllowedWebsitesSelectionCoordinator.canRemoveSelection(
                selectedIndexes: IndexSet([1]),
                visibleRulesCount: 3
            ) == true
        )
    }

    @Test("Import coordinator builds candidates with already-allowed state and selection extraction")
    func importCoordinatorCandidatesAndSelection() {
        let existing = RuleSet(
            name: "Work",
            urls: ["https://www.youtube.com/watch?v=abc123", "github.com"]
        )
        let candidates = AllowedWebsitesImportCoordinator.buildCandidates(
            currentOpenUrls: [
                "https://www.youtube.com/watch?v=abc123",
                "https://example.com/path",
                "https://example.com/path",
            ],
            selectedSet: existing
        )

        #expect(candidates.count == 2)
        #expect(candidates[0].isSelectable == false)
        #expect(candidates[0].defaultSelected == false)
        #expect(candidates[0].title.contains("already allowed"))
        #expect(candidates[1].isSelectable == true)
        #expect(candidates[1].defaultSelected == true)

        let selectedRules = AllowedWebsitesImportCoordinator.selectedRulesToImport(
            candidates: candidates,
            checkboxStates: [.on, .on]
        )
        #expect(selectedRules == [candidates[1].rule])
    }
}
