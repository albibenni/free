import Foundation
import Testing

@testable import FreeLogic

struct AppStateRuleSetCoordinatorTests {
    @Test("mutateRule enforces strict-mode guard")
    func mutateRuleStrictGuard() {
        let set = RuleSet(name: "Default", urls: [])

        let blocked = AppStateRuleSetCoordinator.mutateRule(
            "example.com",
            setId: set.id,
            currentRuleSets: [set],
            isStrictActive: true,
            mutation: .add
        )
        #expect(blocked == [set])

        let allowed = AppStateRuleSetCoordinator.mutateRule(
            "example.com",
            setId: set.id,
            currentRuleSets: [set],
            isStrictActive: false,
            mutation: .add
        )
        #expect(allowed.first?.urls.contains("example.com") == true)
    }

    @Test("createRuleSet and deleteRuleSet keep active selection coherent")
    func createAndDeleteKeepActiveSelectionCoherent() {
        let initial = RuleSet.defaultSet()

        let created = AppStateRuleSetCoordinator.createRuleSet(
            name: "Work",
            makeActive: true,
            currentRuleSets: [initial],
            currentActiveRuleSetId: initial.id
        )
        #expect(created.ruleSets.count == 2)
        #expect(created.activeRuleSetId == created.created.id)

        let deleted = AppStateRuleSetCoordinator.deleteRuleSet(
            id: created.created.id,
            currentRuleSets: created.ruleSets,
            currentActiveRuleSetId: created.activeRuleSetId,
            isStrictActive: false
        )
        #expect(deleted.ruleSets.count == 1)
        #expect(deleted.activeRuleSetId == initial.id)
    }

    @Test("selectActiveRuleSet respects strict mode and unknown ids")
    func selectActiveRuleSetRules() {
        let first = RuleSet.defaultSet()
        let second = RuleSet(name: "Second", urls: [])
        let all = [first, second]

        let selected = AppStateRuleSetCoordinator.selectActiveRuleSet(
            second.id,
            currentRuleSets: all,
            currentActiveRuleSetId: first.id,
            isStrictActive: false
        )
        #expect(selected == second.id)

        let strictSelected = AppStateRuleSetCoordinator.selectActiveRuleSet(
            second.id,
            currentRuleSets: all,
            currentActiveRuleSetId: first.id,
            isStrictActive: true
        )
        #expect(strictSelected == first.id)

        let unknown = AppStateRuleSetCoordinator.selectActiveRuleSet(
            UUID(),
            currentRuleSets: all,
            currentActiveRuleSetId: first.id,
            isStrictActive: false
        )
        #expect(unknown == first.id)
    }
}
