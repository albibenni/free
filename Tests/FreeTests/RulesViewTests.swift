import AppKit
import Foundation
import Testing

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
    private func host(
        _ controller: NSViewController,
        size: CGSize = CGSize(width: 900, height: 760)
    ) -> NSView {
        controller.loadViewIfNeeded()
        controller.view.frame = NSRect(origin: .zero, size: size)
        controller.view.layoutSubtreeIfNeeded()
        controller.view.displayIfNeeded()
        return controller.view
    }

    private func visibleText(in view: NSView) -> [String] {
        guard !view.isHidden, view.alphaValue > 0.001 else { return [] }

        var values: [String] = []
        if let label = view as? NSTextField, !label.stringValue.isEmpty {
            values.append(label.stringValue)
        }
        if let button = view as? NSButton, !button.title.isEmpty {
            values.append(button.title)
        }

        for subview in view.subviews {
            values.append(contentsOf: visibleText(in: subview))
        }
        return values
    }

    @Test("Rules section support covers helper branches")
    func rulesSectionSupportHelpers() {
        #expect(RulesSectionSupport.shouldShowDeleteSetButton(ruleSetCount: 2, isBlocking: false))
        #expect(!RulesSectionSupport.shouldShowDeleteSetButton(ruleSetCount: 1, isBlocking: false))
        #expect(!RulesSectionSupport.shouldShowDeleteSetButton(ruleSetCount: 2, isBlocking: true))

        #expect(RulesSectionSupport.sidebarToggleIcon(isSidebarVisible: true) == "chevron.left")
        #expect(RulesSectionSupport.sidebarToggleIcon(isSidebarVisible: false) == "chevron.right")

        #expect(
            RulesSectionSupport.suggestionsEmptyText(currentOpenUrls: [])
                == "No open tabs detected."
        )
        #expect(
            RulesSectionSupport.suggestionsEmptyText(currentOpenUrls: ["https://example.com"])
                == "All open tabs are already allowed."
        )

        let existing = RuleSet(name: "Test", urls: ["google.com", "youtube.com/watch?v=123"])
        let suggestions = [
            "https://www.google.com",
            "https://github.com",
            "https://youtube.com/watch?v=123",
            "https://youtube.com/watch?v=456",
        ]
        let filtered = RulesSectionSupport.filterSuggestions(suggestions, existing: existing)
        #expect(filtered.count == 2)
        #expect(filtered.contains("https://github.com"))
        #expect(filtered.contains("https://youtube.com/watch?v=456"))

        let existingForImport = RuleSet(
            name: "Import Existing",
            urls: ["https://google.com/*", "https://youtube.com/watch?v=123"]
        )
        let importable = RulesSectionSupport.importableWebsiteCandidates(
            from: [
                "https://www.github.com/pulls",
                "https://github.com/issues",
                "https://google.com/search?q=1",
                "https://youtube.com/watch?v=123",
                "https://youtube.com/watch?v=456",
                "about:blank",
                "localhost:10000",
            ],
            existing: existingForImport
        )
        #expect(importable.count == 5)
        #expect(importable.contains(where: { $0.rule == "github.com/pulls" && !$0.isAlreadyAllowed }))
        #expect(importable.contains(where: { $0.rule == "github.com/issues" && !$0.isAlreadyAllowed }))
        #expect(importable.contains(where: { $0.rule == "youtube.com/watch?v=456" && !$0.isAlreadyAllowed }))
        #expect(importable.contains(where: { $0.rule == "youtube.com/watch?v=123" && $0.isAlreadyAllowed }))
        #expect(importable.contains(where: { $0.rule == "google.com/search?q=1" && !$0.isAlreadyAllowed }))

        let importExactVsHost = RulesSectionSupport.importableWebsiteCandidates(
            from: [
                "https://youtube.com/watch?v=999",
                "https://news.ycombinator.com/item?id=1",
            ],
            existing: RuleSet(
                name: "ExactVsHost",
                urls: ["https://youtube.com/watch?v=123", "news.ycombinator.com"]
            )
        )
        #expect(importExactVsHost.contains(where: { $0.rule == "youtube.com/watch?v=999" && !$0.isAlreadyAllowed }))
        #expect(importExactVsHost.contains(where: { $0.rule == "news.ycombinator.com/item?id=1" && !$0.isAlreadyAllowed }))

        let wildcardRegression = RulesSectionSupport.importableWebsiteCandidates(
            from: [
                "https://www.youtube.com/watch?v=NZi0cJy8Eic",
                "https://www.youtube.com/watch?v=abc123",
            ],
            existing: RuleSet(
                name: "Wildcard Regression",
                urls: ["https://gemini.google.com/*"]
            )
        )
        #expect(wildcardRegression.allSatisfy { !$0.isAlreadyAllowed })
    }

    @Test("Rules sheet controller actions mutate rule-set state and UI state")
    @MainActor
    func rulesSheetControllerActionCoverage() throws {
        let appState = isolatedAppState(name: "actions")
        let setA = RuleSet(name: "Set A", urls: ["a.com"])
        let setB = RuleSet(name: "Set B", urls: ["b.com"])
        appState.ruleSets = [setA, setB]
        appState.activeRuleSetId = setA.id

        let controller = RulesSheetViewController(appState: appState)
        _ = host(controller)

        controller.createSetForTesting(name: "Created Set")
        #expect(appState.ruleSets.count == 3)
        let createdSet = try #require(appState.ruleSets.last)
        #expect(controller.selectedSetIdForTesting == createdSet.id)

        controller.toggleSidebarForTesting()
        #expect(controller.isSidebarVisibleForTesting == false)
        controller.toggleSidebarForTesting()
        #expect(controller.isSidebarVisibleForTesting)

        controller.toggleSuggestionsForTesting()
        #expect(controller.isSuggestionsExpandedForTesting)
        appState.currentOpenUrls = ["https://open.example.com"]
        controller.refreshSuggestionsForTesting()
        #expect(appState.currentOpenUrls == [])

        controller.addSuggestionForTesting(url: "manual-add.com", setId: setA.id)
        #expect(appState.ruleSets.first(where: { $0.id == setA.id })?.containsRule("manual-add.com") == true)

        controller.addRuleForTesting("new-rule.com", setId: setA.id)
        #expect(appState.ruleSets.first(where: { $0.id == setA.id })?.containsRule("new-rule.com") == true)

        controller.selectRuleSetForTesting(setB)
        #expect(controller.selectedSetIdForTesting == setB.id)

        appState.isBlocking = true
        controller.selectRuleSetForTesting(setA)
        #expect(controller.selectedSetIdForTesting == setB.id)

        appState.isBlocking = false
        controller.deleteRuleSetForTesting(setB)
        #expect(appState.ruleSets.contains(where: { $0.id == setB.id }) == false)
    }

    @Test("Rules sheet controller filteredSuggestions bridges app open URLs against selected set")
    @MainActor
    func rulesSheetControllerFilteredSuggestions() {
        let appState = isolatedAppState(name: "filteredSuggestions")
        let set = RuleSet(name: "Set", urls: ["google.com"])
        appState.ruleSets = [set]

        let controller = RulesSheetViewController(appState: appState)
        _ = host(controller)
        appState.currentOpenUrls = ["https://google.com", "https://github.com"]

        let filtered = controller.filteredSuggestionsForTesting(for: set)
        #expect(filtered.count == 1)
        #expect(filtered.first == "https://github.com")
    }

    @Test("Rules sheet controller renders selected-set paths with collapsed and expanded empty suggestions")
    @MainActor
    func rulesSheetControllerRenderSelectedSetVariants() {
        let appState = isolatedAppState(name: "renderSelectedVariants")
        let setA = RuleSet(name: "Set A", urls: ["a.com"])
        let setB = RuleSet(name: "Set B", urls: ["b.com"])
        appState.ruleSets = [setA, setB]
        appState.activeRuleSetId = setA.id

        let controller = RulesSheetViewController(appState: appState)
        let hosted = host(controller)
        var texts = visibleText(in: hosted)
        #expect(texts.contains("Set A"))
        #expect(texts.contains("Allowed in this list"))
        #expect(texts.contains("Open Tabs Suggestions"))

        appState.currentOpenUrls = []
        controller.setSuggestionsExpandedForTesting(true)
        texts = visibleText(in: hosted)
        #expect(texts.contains("No open tabs detected."))
    }

    @Test("Rules sheet controller skips reload for unrelated state changes while suggestions are collapsed")
    @MainActor
    func rulesSheetControllerSkipsReloadForUnrelatedStateChanges() {
        let appState = isolatedAppState(name: "unrelatedReload")
        let set = RuleSet(name: "Set", urls: ["a.com"])
        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id

        let controller = RulesSheetViewController(appState: appState)
        _ = host(controller)
        let initialReloadGeneration = controller.reloadGenerationForTesting

        appState.pomodoroFocusDuration = 50
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        #expect(controller.reloadGenerationForTesting == initialReloadGeneration)
    }

    @Test("Rules sheet controller reuses sidebar row views when selection changes")
    @MainActor
    func rulesSheetControllerReusesSidebarRowsOnSelection() throws {
        let appState = isolatedAppState(name: "sidebarReuseOnSelection")
        let setA = RuleSet(name: "Set A", urls: ["a.com"])
        let setB = RuleSet(name: "Set B", urls: ["b.com"])
        appState.ruleSets = [setA, setB]
        appState.activeRuleSetId = setA.id

        let controller = RulesSheetViewController(appState: appState)
        _ = host(controller)

        let initialReloadGeneration = controller.reloadGenerationForTesting
        let setARowId = try #require(controller.sidebarRowObjectIdentifierForTesting(setA.id))
        let setBRowId = try #require(controller.sidebarRowObjectIdentifierForTesting(setB.id))

        controller.selectRuleSetForTesting(setB)

        #expect(controller.reloadGenerationForTesting == initialReloadGeneration)
        #expect(controller.sidebarRowObjectIdentifierForTesting(setA.id) == setARowId)
        #expect(controller.sidebarRowObjectIdentifierForTesting(setB.id) == setBRowId)
        #expect(controller.selectedSetIdForTesting == setB.id)
    }

    @Test("Rules sheet controller reuses existing rule row views for unchanged rules")
    @MainActor
    func rulesSheetControllerReusesRuleRows() throws {
        let appState = isolatedAppState(name: "ruleRowsReuse")
        let set = RuleSet(name: "Set", urls: ["a.com"])
        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id

        let controller = RulesSheetViewController(appState: appState)
        _ = host(controller)

        let initialRowId = try #require(controller.ruleRowObjectIdentifierForTesting("a.com"))

        controller.addRuleForTesting("b.com", setId: set.id)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        #expect(controller.ruleRowObjectIdentifierForTesting("a.com") == initialRowId)
        #expect(controller.ruleRowObjectIdentifierForTesting("b.com") != nil)
    }

    @Test("Rules sheet controller renders non-empty suggestions and no-selected-list fallback")
    @MainActor
    func rulesSheetControllerRenderSuggestionsAndFallback() {
        let appState = isolatedAppState(name: "renderSuggestionsAndFallback")
        let set = RuleSet(name: "Set", urls: ["already.com"])
        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id

        let controller = RulesSheetViewController(appState: appState)
        let hosted = host(controller)

        appState.currentOpenUrls = ["https://newsite.com"]
        controller.setSuggestionsExpandedForTesting(true)
        var texts = visibleText(in: hosted)
        #expect(texts.contains("https://newsite.com"))
        #expect(texts.contains("Add"))

        let emptyAppState = isolatedAppState(name: "renderNoSelection")
        let emptyController = RulesSheetViewController(appState: emptyAppState)
        let emptyHosted = host(emptyController)
        emptyAppState.ruleSets = []
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        texts = visibleText(in: emptyHosted)
        #expect(texts.contains("Select a list to edit"))
    }
}
