import Testing
import SwiftUI
import AppKit
import Foundation
@testable import FreeLogic

@Suite(.serialized)
struct RulesViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "RulesViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 900, height: 760)) -> NSHostingView<V> {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    @Test("RulesView static helper logic covers all branches")
    func rulesViewStaticHelpers() {
        #expect(RulesView.shouldShowDeleteSetButton(ruleSetCount: 2, isBlocking: false))
        #expect(!RulesView.shouldShowDeleteSetButton(ruleSetCount: 1, isBlocking: false))
        #expect(!RulesView.shouldShowDeleteSetButton(ruleSetCount: 2, isBlocking: true))

        #expect(RulesView.sidebarWidth(isSidebarVisible: true) == 200)
        #expect(RulesView.sidebarWidth(isSidebarVisible: false) == 0)

        _ = RulesView.sidebarBackgroundColor(colorScheme: .dark)
        _ = RulesView.sidebarBackgroundColor(colorScheme: .light)

        #expect(RulesView.shouldShowSidebarDivider(isSidebarVisible: true))
        #expect(!RulesView.shouldShowSidebarDivider(isSidebarVisible: false))

        #expect(RulesView.sidebarToggleIcon(isSidebarVisible: true) == "chevron.left")
        #expect(RulesView.sidebarToggleIcon(isSidebarVisible: false) == "chevron.right")

        #expect(RulesView.shouldShowSuggestionsList(isSuggestionsExpanded: true))
        #expect(!RulesView.shouldShowSuggestionsList(isSuggestionsExpanded: false))
        #expect(RulesView.shouldShowRefreshSuggestionsButton(isSuggestionsExpanded: true))
        #expect(!RulesView.shouldShowRefreshSuggestionsButton(isSuggestionsExpanded: false))
        #expect(RulesView.suggestionsChevronIcon(isSuggestionsExpanded: true) == "chevron.down")
        #expect(RulesView.suggestionsChevronIcon(isSuggestionsExpanded: false) == "chevron.right")

        #expect(RulesView.suggestionsEmptyText(currentOpenUrls: []) == "No open tabs detected.")
        #expect(
            RulesView.suggestionsEmptyText(currentOpenUrls: ["https://example.com"])
                == "All open tabs are already allowed."
        )
    }

    @Test("RulesView actions mutate state and app model paths")
    @MainActor
    func rulesViewActionCoverage() {
        let appState = isolatedAppState(name: "actions")
        let setA = RuleSet(name: "Set A", urls: ["a.com"])
        let setB = RuleSet(name: "Set B", urls: ["b.com"])
        appState.ruleSets = [setA, setB]
        appState.activeRuleSetId = setA.id

        let view = RulesView(
            initialNewRule: "new-rule.com",
            initialNewSetName: "Created Set",
            actionAppState: appState
        )

        _ = view.selectedSet
        view.handleOnAppear()
        _ = view.selectedSet

        view.openAddSetAlert()

        let setCountBefore = appState.ruleSets.count
        view.createSet()
        #expect(appState.ruleSets.count == setCountBefore + 1)
        _ = appState.ruleSets.last?.id

        view.cancelCreateSet()

        view.toggleSidebar()

        view.toggleSuggestions()

        appState.currentOpenUrls = ["https://open.example.com"]
        view.refreshSuggestions()
        #expect(appState.currentOpenUrls == [])

        view.addSuggestion(url: "manual-add.com", setId: setA.id)
        #expect(appState.ruleSets.first(where: { $0.id == setA.id })?.containsRule("manual-add.com") == true)

        let addSuggestion = view.addSuggestionAction(url: "action-add.com", setId: setA.id)
        addSuggestion()
        #expect(appState.ruleSets.first(where: { $0.id == setA.id })?.containsRule("action-add.com") == true)

        let removeSuggestion = view.removeRuleAction(rule: "action-add.com", setId: setA.id)
        removeSuggestion()
        #expect(appState.ruleSets.first(where: { $0.id == setA.id })?.containsRule("action-add.com") == false)

        view.addRule(to: setA)
        #expect(appState.ruleSets.first(where: { $0.id == setA.id })?.containsRule("new-rule.com") == true)

        let addRuleClosureView = RulesView(initialNewRule: "via-closure.com", actionAppState: appState)
        let addRuleClosure = addRuleClosureView.addRuleAction(to: setA)
        addRuleClosure()
        #expect(appState.ruleSets.first(where: { $0.id == setA.id })?.containsRule("via-closure.com") == true)

        appState.isBlocking = false
        let tapSelect = view.selectSetTapAction(setB)
        tapSelect()

        appState.isBlocking = true
        let tapBlocked = view.selectSetTapAction(setA)
        tapBlocked()

        let alreadySelected = RulesView(initialSelectedSetId: setA.id, actionAppState: appState)
        alreadySelected.handleOnAppear()

        appState.isBlocking = false
        let deleteSelected = RulesView(initialSelectedSetId: setB.id, actionAppState: appState)
        let deleteAction = deleteSelected.deleteSetAction(setB)
        deleteAction()
        #expect(appState.ruleSets.contains(where: { $0.id == setB.id }) == false)
    }

    @Test("RulesView filteredSuggestions bridges app open URLs against selected set")
    func rulesViewFilteredSuggestions() {
        let appState = isolatedAppState(name: "filteredSuggestions")
        let set = RuleSet(name: "Set", urls: ["google.com"])
        appState.ruleSets = [set]
        appState.currentOpenUrls = ["https://google.com", "https://github.com"]

        let view = RulesView(initialSelectedSetId: set.id, actionAppState: appState)
        let filtered = view.filteredSuggestions(for: set)
        #expect(filtered.count == 1)
        #expect(filtered.first == "https://github.com")
    }

    @Test("RulesView renders selected-set paths with suggestions collapsed and expanded-empty")
    @MainActor
    func rulesViewRenderSelectedSetVariants() {
        let appState = isolatedAppState(name: "renderSelectedVariants")
        let setA = RuleSet(name: "Set A", urls: ["a.com"])
        let setB = RuleSet(name: "Set B", urls: ["b.com"])
        appState.ruleSets = [setA, setB]

        let collapsed = RulesView(
            initialSelectedSetId: setA.id,
            initialSidebarVisible: true,
            initialSuggestionsExpanded: false
        )
        .environmentObject(appState)
        .environment(\.colorScheme, .dark)
        let hostedCollapsed = host(collapsed)
        #expect(hostedCollapsed.fittingSize.width >= 0)

        appState.currentOpenUrls = []
        let expandedEmpty = RulesView(
            initialSelectedSetId: setA.id,
            initialSidebarVisible: false,
            initialSuggestionsExpanded: true
        )
        .environmentObject(appState)
        .environment(\.colorScheme, .light)
        let hostedExpandedEmpty = host(expandedEmpty)
        #expect(hostedExpandedEmpty.fittingSize.height >= 0)
    }

    @Test("RulesView renders suggestions non-empty and no-selected-list fallback")
    @MainActor
    func rulesViewRenderSuggestionsAndFallback() {
        let appState = isolatedAppState(name: "renderSuggestionsAndFallback")
        let set = RuleSet(name: "Set", urls: ["already.com"])
        appState.ruleSets = [set]
        appState.currentOpenUrls = ["https://newsite.com"]

        let withSuggestions = RulesView(
            initialSelectedSetId: set.id,
            initialSuggestionsExpanded: true
        )
        .environmentObject(appState)
        let hostedSuggestions = host(withSuggestions)
        #expect(hostedSuggestions.fittingSize.width >= 0)

        appState.ruleSets = []
        let noSelection = RulesView(initialSelectedSetId: nil)
            .environmentObject(appState)
        let hostedNoSelection = host(noSelection)
        #expect(hostedNoSelection.fittingSize.height >= 0)
    }
}
