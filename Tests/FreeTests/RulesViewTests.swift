import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct RulesViewTests {
    private final class ActionTarget: NSObject {
        @objc
        func noop(_: Any?) {}
    }

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

    @Test("Rules sheet observation signature covers nil-controller fallback and live-controller path")
    @MainActor
    func rulesSheetObservationSignatureCoverage() {
        let appState = isolatedAppState(name: "observationSignatureCoverage")
        let set = RuleSet(name: "Set A", urls: ["a.com"])
        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id
        appState.currentOpenUrls = ["https://open.example.com"]

        let fallback = RulesSheetViewController.observationSignature(
            controller: nil,
            appState: appState
        )
        #expect(fallback.selectedSetId == set.id)
        #expect(fallback.currentOpenUrls.isEmpty)

        let controller = RulesSheetViewController(appState: appState)
        _ = host(controller)
        controller.setSuggestionsExpandedForTesting(true)
        let live = RulesSheetViewController.observationSignature(
            controller: controller,
            appState: appState
        )
        #expect(live.selectedSetId == set.id)
        #expect(live.currentOpenUrls == appState.currentOpenUrls)
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

    @Test("Rules sheet canReuseSidebarRows returns false when row IDs are incomplete despite matching count")
    @MainActor
    func rulesSheetCanReuseSidebarRowsIncompleteIds() {
        let appState = isolatedAppState(name: "sidebarReuseIncompleteIds")
        let setA = RuleSet(name: "Set A", urls: ["a.com"])
        let setB = RuleSet(name: "Set B", urls: ["b.com"])
        appState.ruleSets = [setA, setB]
        appState.activeRuleSetId = setA.id

        let controller = RulesSheetViewController(appState: appState)
        _ = host(controller)

        let rowA = RulesSheetLayoutBuilder.makeSidebarRow(
            ruleSet: setA,
            isSelected: true,
            canDelete: true,
            onSelect: #selector(RulesSheetViewController.selectRuleSet(_:)),
            onDelete: #selector(RulesSheetViewController.deleteRuleSet(_:)),
            target: controller
        )
        let rowB = RulesSheetLayoutBuilder.makeSidebarRow(
            ruleSet: setB,
            isSelected: false,
            canDelete: true,
            onSelect: #selector(RulesSheetViewController.selectRuleSet(_:)),
            onDelete: #selector(RulesSheetViewController.deleteRuleSet(_:)),
            target: controller
        )

        controller.sidebarRowsById = [setA.id: rowA, UUID(): rowB]
        #expect(controller.sidebarRowsById.count == appState.ruleSets.count)
        #expect(controller.canReuseSidebarRows(rows: appState.ruleSets) == false)
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

    @Test("Rules sheet controller reuses suggestion rows across accent updates and expand toggles")
    @MainActor
    func rulesSheetControllerReusesSuggestionRows() throws {
        let appState = isolatedAppState(name: "suggestionsReuse")
        let set = RuleSet(name: "Set", urls: ["already.com"])
        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id

        let controller = RulesSheetViewController(appState: appState)
        _ = host(controller)

        appState.currentOpenUrls = ["https://newsite.com"]
        controller.setSuggestionsExpandedForTesting(true)
        let initialSuggestionRowId = try #require(
            controller.suggestionRowObjectIdentifierForTesting("https://newsite.com")
        )

        appState.accentColorIndex = 3
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        #expect(
            controller.suggestionRowObjectIdentifierForTesting("https://newsite.com")
                == initialSuggestionRowId
        )

        controller.setSuggestionsExpandedForTesting(false)
        controller.setSuggestionsExpandedForTesting(true)
        #expect(
            controller.suggestionRowObjectIdentifierForTesting("https://newsite.com")
                == initialSuggestionRowId
        )
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

    @Test("Rules sheet objc actions cover add/select/delete/suggestion/done branches")
    @MainActor
    func rulesSheetControllerObjcActionsCoverage() throws {
        defer { RulesSheetAlertPresenter.resetForTesting() }

        let appState = isolatedAppState(name: "objcActionsCoverage")
        let setA = RuleSet(name: "Set A", urls: ["a.com"])
        let setB = RuleSet(name: "Set B", urls: ["b.com"])
        appState.ruleSets = [setA, setB]
        appState.activeRuleSetId = setA.id

        var doneCount = 0
        let controller = RulesSheetViewController(appState: appState) {
            doneCount += 1
        }
        _ = host(controller)

        // addRuleSet: create path
        RulesSheetAlertPresenter.makeAlert = { NSAlert() }
        RulesSheetAlertPresenter.runModal = { alert in
            (alert.accessoryView as? NSTextField)?.stringValue = "Set C"
            return .alertFirstButtonReturn
        }
        controller.addRuleSet()
        #expect(appState.ruleSets.contains(where: { $0.name == "Set C" }))

        // addRuleSet: cancel path
        let setCountAfterCreate = appState.ruleSets.count
        RulesSheetAlertPresenter.runModal = { _ in .alertSecondButtonReturn }
        controller.addRuleSet()
        #expect(appState.ruleSets.count == setCountAfterCreate)

        // selectRuleSet: guard and success branches
        controller.selectRuleSet(NSButton())
        #expect(controller.selectedSetIdForTesting != nil)
        let selectButton = NSButton()
        selectButton.identifier = NSUserInterfaceItemIdentifier(setB.id.uuidString)
        controller.selectRuleSet(selectButton)
        #expect(controller.selectedSetIdForTesting == setB.id)

        // deleteRuleSet: guard and success branches
        controller.deleteRuleSet(NSButton())
        #expect(appState.ruleSets.contains(where: { $0.id == setA.id }))
        let deleteButton = NSButton()
        deleteButton.identifier = NSUserInterfaceItemIdentifier(setA.id.uuidString)
        controller.deleteRuleSet(deleteButton)
        #expect(appState.ruleSets.contains(where: { $0.id == setA.id }) == false)

        // addRule: selected + guard (no selected set)
        controller.selectedSetId = setB.id
        controller.addRuleField.stringValue = "added-from-action.com"
        controller.addRule()
        #expect(
            appState.ruleSets.first(where: { $0.id == setB.id })?
                .containsRule("added-from-action.com") == true
        )
        #expect(controller.addRuleField.stringValue.isEmpty)
        controller.selectedSetId = UUID()
        controller.addRuleField.stringValue = "guard-should-not-add.com"
        controller.addRule()
        #expect(
            appState.ruleSets.first(where: { $0.id == setB.id })?
                .containsRule("guard-should-not-add.com") == false
        )

        // deleteRule: guard and success branches
        controller.deleteRule(NSButton())
        controller.selectedSetId = setB.id
        let deleteRuleButton = NSButton()
        deleteRuleButton.identifier = NSUserInterfaceItemIdentifier("b.com")
        controller.deleteRule(deleteRuleButton)
        #expect(
            appState.ruleSets.first(where: { $0.id == setB.id })?
                .containsRule("b.com") == false
        )

        // toggleSuggestions: both states
        let previousExpanded = controller.isSuggestionsExpandedForTesting
        controller.toggleSuggestions()
        #expect(controller.isSuggestionsExpandedForTesting != previousExpanded)
        controller.toggleSuggestions()
        #expect(controller.isSuggestionsExpandedForTesting == previousExpanded)

        // addSuggestion: guard and success branches
        controller.addSuggestion(NSButton())
        let suggestionButton = NSButton()
        suggestionButton.identifier = NSUserInterfaceItemIdentifier("suggested.com")
        controller.selectedSetId = setB.id
        controller.addSuggestion(suggestionButton)
        #expect(
            appState.ruleSets.first(where: { $0.id == setB.id })?
                .containsRule("suggested.com") == true
        )

        controller.handleDone()
        #expect(doneCount == 1)
    }

    @Test("Rules layout builder covers sidebar delete teardown and row reorder/trim branches")
    @MainActor
    func rulesLayoutBuilderReorderAndTrimCoverage() {
        let target = ActionTarget()
        let onSelect = #selector(ActionTarget.noop(_:))
        let onDelete = #selector(ActionTarget.noop(_:))
        let onAdd = #selector(ActionTarget.noop(_:))

        let setA = RuleSet(name: "A", urls: ["a.com"])
        let sidebarRow = RulesSheetLayoutBuilder.makeSidebarRow(
            ruleSet: setA,
            isSelected: true,
            canDelete: true,
            onSelect: onSelect,
            onDelete: onDelete,
            target: target
        )
        #expect(sidebarRow.arrangedSubviews.count == 3)
        sidebarRow.configure(
            title: setA.name,
            ruleSetId: setA.id,
            isSelected: false,
            canDelete: false,
            onSelect: onSelect,
            onDelete: onDelete,
            target: target
        )
        #expect(sidebarRow.arrangedSubviews.count == 2)

        let rulesStack = NSStackView()
        let ruleA = RulesSheetLayoutBuilder.makeRuleRow(rule: "a.com", onDelete: onDelete, target: target)
        let ruleB = RulesSheetLayoutBuilder.makeRuleRow(rule: "b.com", onDelete: onDelete, target: target)
        rulesStack.addArrangedSubview(ruleB)
        rulesStack.addArrangedSubview(ruleA)
        rulesStack.addArrangedSubview(NSView())

        let reorderedRuleRows = RulesSheetLayoutBuilder.updateOrRebuildRuleRows(
            in: rulesStack,
            rules: ["a.com", "b.com"],
            existingRows: ["a.com": ruleA, "b.com": ruleB],
            onDelete: onDelete,
            target: target
        )
        #expect(reorderedRuleRows.count == 2)
        #expect(rulesStack.arrangedSubviews.count == 2)
        #expect((rulesStack.arrangedSubviews[0] as? RulesSheetRuleRowView)?.rule == "a.com")
        #expect((rulesStack.arrangedSubviews[1] as? RulesSheetRuleRowView)?.rule == "b.com")

        let suggestionStack = NSStackView()
        let suggestionA = RulesSheetLayoutBuilder.makeSuggestionRow(
            suggestion: "https://a.com",
            accentColor: .systemBlue,
            onAdd: onAdd,
            target: target
        )
        let suggestionB = RulesSheetLayoutBuilder.makeSuggestionRow(
            suggestion: "https://b.com",
            accentColor: .systemBlue,
            onAdd: onAdd,
            target: target
        )
        suggestionStack.addArrangedSubview(suggestionB)
        suggestionStack.addArrangedSubview(suggestionA)
        suggestionStack.addArrangedSubview(NSView())

        let reorderedSuggestionRows = RulesSheetLayoutBuilder.updateOrRebuildSuggestionRows(
            in: suggestionStack,
            suggestions: ["https://a.com", "https://b.com"],
            accentColor: .systemGreen,
            existingRows: ["https://a.com": suggestionA, "https://b.com": suggestionB],
            onAdd: onAdd,
            target: target
        )
        #expect(reorderedSuggestionRows.count == 2)
        #expect(suggestionStack.arrangedSubviews.count == 2)
        #expect((suggestionStack.arrangedSubviews[0] as? RulesSheetSuggestionRowView)?.suggestion == "https://a.com")
        #expect((suggestionStack.arrangedSubviews[1] as? RulesSheetSuggestionRowView)?.suggestion == "https://b.com")

        // Cover insert-and-continue branches when existing rows are detached.
        let detachedRulesStack = NSStackView()
        let detachedRuleRow = RulesSheetLayoutBuilder.makeRuleRow(rule: "detached.com", onDelete: onDelete, target: target)
        let detachedRules = RulesSheetLayoutBuilder.updateOrRebuildRuleRows(
            in: detachedRulesStack,
            rules: ["detached.com"],
            existingRows: ["detached.com": detachedRuleRow],
            onDelete: onDelete,
            target: target
        )
        #expect(detachedRulesStack.arrangedSubviews.count == 1)
        #expect((detachedRulesStack.arrangedSubviews.first as? RulesSheetRuleRowView)?.rule == "detached.com")
        #expect(detachedRules["detached.com"] === detachedRuleRow)

        let detachedSuggestionsStack = NSStackView()
        let detachedSuggestionRow = RulesSheetLayoutBuilder.makeSuggestionRow(
            suggestion: "https://detached.com",
            accentColor: .systemBlue,
            onAdd: onAdd,
            target: target
        )
        let detachedSuggestions = RulesSheetLayoutBuilder.updateOrRebuildSuggestionRows(
            in: detachedSuggestionsStack,
            suggestions: ["https://detached.com"],
            accentColor: .systemGreen,
            existingRows: ["https://detached.com": detachedSuggestionRow],
            onAdd: onAdd,
            target: target
        )
        #expect(detachedSuggestionsStack.arrangedSubviews.count == 1)
        #expect((detachedSuggestionsStack.arrangedSubviews.first as? RulesSheetSuggestionRowView)?.suggestion == "https://detached.com")
        #expect(detachedSuggestions["https://detached.com"] === detachedSuggestionRow)

        // Cover currentAtIndex nil branch when row still has superview but is not arranged.
        let nonArrangedRuleStack = NSStackView()
        let nonArrangedRuleRow = RulesSheetLayoutBuilder.makeRuleRow(rule: "edge.com", onDelete: onDelete, target: target)
        nonArrangedRuleStack.addArrangedSubview(nonArrangedRuleRow)
        nonArrangedRuleStack.removeArrangedSubview(nonArrangedRuleRow)
        let edgeRules = RulesSheetLayoutBuilder.updateOrRebuildRuleRows(
            in: nonArrangedRuleStack,
            rules: ["edge.com"],
            existingRows: ["edge.com": nonArrangedRuleRow],
            onDelete: onDelete,
            target: target
        )
        #expect((nonArrangedRuleStack.arrangedSubviews.first as? RulesSheetRuleRowView)?.rule == "edge.com")
        #expect(edgeRules["edge.com"] === nonArrangedRuleRow)

        let nonArrangedSuggestionStack = NSStackView()
        let nonArrangedSuggestionRow = RulesSheetLayoutBuilder.makeSuggestionRow(
            suggestion: "https://edge.com",
            accentColor: .systemBlue,
            onAdd: onAdd,
            target: target
        )
        nonArrangedSuggestionStack.addArrangedSubview(nonArrangedSuggestionRow)
        nonArrangedSuggestionStack.removeArrangedSubview(nonArrangedSuggestionRow)
        let edgeSuggestions = RulesSheetLayoutBuilder.updateOrRebuildSuggestionRows(
            in: nonArrangedSuggestionStack,
            suggestions: ["https://edge.com"],
            accentColor: .systemGreen,
            existingRows: ["https://edge.com": nonArrangedSuggestionRow],
            onAdd: onAdd,
            target: target
        )
        #expect((nonArrangedSuggestionStack.arrangedSubviews.first as? RulesSheetSuggestionRowView)?.suggestion == "https://edge.com")
        #expect(edgeSuggestions["https://edge.com"] === nonArrangedSuggestionRow)
    }

    @Test("Rules layout row NSCoder init paths return nil")
    @MainActor
    func rulesLayoutRowCoderInitCoverage() throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.finishEncoding()
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        defer { unarchiver.finishDecoding() }

        #expect(RulesSheetSidebarRowView(coder: unarchiver) == nil)
        #expect(RulesSheetRuleRowView(coder: unarchiver) == nil)
        #expect(RulesSheetSuggestionRowView(coder: unarchiver) == nil)
    }
}
