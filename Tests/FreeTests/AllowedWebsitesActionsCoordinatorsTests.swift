import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct AllowedWebsitesActionsCoordinatorsTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "AllowedWebsitesActionsCoordinatorsTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @Test("Rule-set actions coordinator guards create/delete and mutates via AppState")
    func ruleSetActionsCoordinator() async throws {
        #expect(AllowedWebsitesRuleSetActionsCoordinator.canCreateRuleSet(isStrictActive: false))
        #expect(!AllowedWebsitesRuleSetActionsCoordinator.canCreateRuleSet(isStrictActive: true))
        #expect(
            AllowedWebsitesRuleSetActionsCoordinator.canDeleteRuleSet(
                isStrictActive: false,
                ruleSetCount: 2
            )
        )
        #expect(
            !AllowedWebsitesRuleSetActionsCoordinator.canDeleteRuleSet(
                isStrictActive: true,
                ruleSetCount: 2
            )
        )

        let appState = isolatedAppState(name: "ruleSetActions")
        let created = AllowedWebsitesRuleSetActionsCoordinator.createRuleSet(
            appState: appState,
            name: "Work"
        )
        #expect(appState.ruleSets.contains(where: { $0.id == created.id }))

        let selected = AllowedWebsitesRuleSetActionsCoordinator.selectedRuleSet(
            id: created.id,
            ruleSets: appState.ruleSets
        )
        #expect(selected?.id == created.id)

        let strictSelection = AllowedWebsitesRuleSetActionsCoordinator.selectedRuleSetAfterRowTap(
            tappedId: UUID(),
            currentSelectedId: created.id,
            isStrictActive: true
        )
        #expect(strictSelection == created.id)

        let relaxedSelection = AllowedWebsitesRuleSetActionsCoordinator.selectedRuleSetAfterRowTap(
            tappedId: created.id,
            currentSelectedId: nil,
            isStrictActive: false
        )
        #expect(relaxedSelection == created.id)

        AllowedWebsitesRuleSetActionsCoordinator.deleteRuleSet(
            appState: appState,
            id: created.id
        )
        #expect(!appState.ruleSets.contains(where: { $0.id == created.id }))
    }

    @Test("Rule actions coordinator normalizes/adds/removes rules")
    func ruleActionsCoordinator() async throws {
        let appState = isolatedAppState(name: "ruleActions")
        let set = AllowedWebsitesRuleSetActionsCoordinator.createRuleSet(appState: appState, name: "A")

        #expect(AllowedWebsitesRuleActionsCoordinator.normalizedRuleInput("  ") == nil)
        #expect(AllowedWebsitesRuleActionsCoordinator.normalizedRuleInput("  example.com  ") == "example.com")

        #expect(
            AllowedWebsitesRuleActionsCoordinator.addRule(
                appState: appState,
                setId: set.id,
                rawValue: "  example.com "
            )
        )
        #expect(
            appState.ruleSets.first(where: { $0.id == set.id })?.urls.contains("example.com") == true
        )

        let removed = AllowedWebsitesRuleActionsCoordinator.removeRules(
            appState: appState,
            setId: set.id,
            rules: ["example.com"]
        )
        #expect(removed == 1)
        #expect(
            appState.ruleSets.first(where: { $0.id == set.id })?.urls.contains("example.com") == false
        )

        let addInvalid = AllowedWebsitesRuleActionsCoordinator.addRule(
            appState: appState,
            setId: set.id,
            rawValue: "   "
        )
        #expect(addInvalid == false)

        let removedEmpty = AllowedWebsitesRuleActionsCoordinator.removeRules(
            appState: appState,
            setId: set.id,
            rules: []
        )
        #expect(removedEmpty == 0)
    }

    @Test("Reload coordinator resolves signature and selected rule-set fallback")
    func reloadCoordinatorState() async throws {
        let appState = isolatedAppState(name: "reloadCoordinator")
        let a = AllowedWebsitesRuleSetActionsCoordinator.createRuleSet(appState: appState, name: "A")
        let b = AllowedWebsitesRuleSetActionsCoordinator.createRuleSet(appState: appState, name: "B")
        appState.activeRuleSetId = b.id

        let state = AllowedWebsitesReloadCoordinator.reloadState(
            appState: appState,
            previousSelectedRuleSetId: UUID()
        )

        #expect(state.selectedRuleSetId == b.id)
        #expect(
            state.renderSignature == AllowedWebsitesReloadCoordinator.renderSignature(
                appState: appState
            )
        )
        #expect(state.renderSignature.ruleSets.contains(where: { $0.id == a.id }))
        #expect(state.renderSignature.ruleSets.contains(where: { $0.id == b.id }))
    }

    @Test("Rule-set actions coordinator function references execute runtime paths")
    func ruleSetActionsCoordinatorFunctionReferences() async throws {
        let createAllowed: (Bool) -> Bool = AllowedWebsitesRuleSetActionsCoordinator.canCreateRuleSet
        let deleteAllowed: (Bool, Int) -> Bool = AllowedWebsitesRuleSetActionsCoordinator.canDeleteRuleSet
        let selectRuleSet: (UUID?, [RuleSet]) -> RuleSet? = AllowedWebsitesRuleSetActionsCoordinator.selectedRuleSet
        let selectionAfterTap: (UUID, UUID?, Bool) -> UUID? =
            AllowedWebsitesRuleSetActionsCoordinator.selectedRuleSetAfterRowTap

        let strictActive = Bool.random()
        let count = Int.random(in: 0...3)
        #expect(createAllowed(strictActive) == !strictActive)
        #expect(deleteAllowed(strictActive, count) == (!strictActive && count > 1))

        let ruleSet = RuleSet(name: "A", urls: ["example.com"])
        let id = ruleSet.id
        let ruleSets = [ruleSet]
        #expect(selectRuleSet(id, ruleSets)?.id == id)
        #expect(selectRuleSet(nil, ruleSets) == nil)

        let tappedId = UUID()
        let currentSelectedId = UUID()
        #expect(selectionAfterTap(tappedId, currentSelectedId, true) == currentSelectedId)
        #expect(selectionAfterTap(tappedId, currentSelectedId, false) == tappedId)
    }
}
