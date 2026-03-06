import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct AllowedWebsitesActionsCoordinatorsTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "AllowedWebsitesActionsCoordinatorsTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @Test("Rule-set actions coordinator guards create/delete and mutates via AppState")
    func ruleSetActionsCoordinator() {
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

        AllowedWebsitesRuleSetActionsCoordinator.deleteRuleSet(
            appState: appState,
            id: created.id
        )
        #expect(!appState.ruleSets.contains(where: { $0.id == created.id }))
    }

    @Test("Rule actions coordinator normalizes/adds/removes rules")
    func ruleActionsCoordinator() {
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
    }
}
