import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct AllowedWebsitesFloatingEditorTests {
    private final class MockBrowserAutomator: BrowserAutomator {
        let urls: [String]

        init(urls: [String]) {
            self.urls = urls
        }

        func getActiveUrl(for _: NSRunningApplication) -> String? { nil }
        func redirect(app _: NSRunningApplication, to _: String) {}
        func getAllOpenUrls(browsers _: [String]) -> [String] { urls }
        func checkPermissions(prompt _: Bool) -> Bool { true }
    }

    private func makeAppState(name: String, openUrls: [String] = []) -> AppState {
        let suite = "AllowedWebsitesFloatingEditorTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let monitor = BrowserMonitor(
            stateSnapshotProvider: { nil },
            onEvent: { _ in },
            server: nil,
            automator: MockBrowserAutomator(urls: openUrls),
            startTimer: false
        )
        return AppState(defaults: defaults, monitor: monitor, isTesting: true)
    }

    @MainActor
    @Test("floating editor layout wires controls and table behavior")
    func layoutWiring() {
        let appState = makeAppState(name: "layoutWiring")
        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: nil
        )
        controller.loadViewIfNeeded()

        #expect(
            controller.ruleSetListHeightConstraint?.constant
                == AllowedWebsitesPresentationCoordinator.ruleSetListHeight(
                    ruleSetCount: appState.ruleSets.count
                )
        )
        #expect(controller.createListButton.target === controller)
        #expect(
            controller.createListButton.action
                == #selector(AllowedWebsitesFloatingEditorViewController.handleCreateRuleSet)
        )
        #expect(controller.deleteListButton.target === controller)
        #expect(
            controller.deleteListButton.action
                == #selector(AllowedWebsitesFloatingEditorViewController.handleDeleteRuleSet)
        )
        #expect(controller.urlField.placeholderString == "Add URL to allow...")
        #expect(controller.urlField.target === controller)
        #expect(
            controller.urlField.action
                == #selector(AllowedWebsitesFloatingEditorViewController.handleAddRuleFromField(_:))
        )
        #expect(controller.rulesTableView.allowsMultipleSelection)
        #expect(controller.rulesTableView.delegate === controller.rulesTableController)
        #expect(controller.rulesTableView.dataSource === controller.rulesTableController)
        #expect(controller.rulesTableView.tableColumns.count == 1)
    }

    @MainActor
    @Test("floating editor add/remove rule actions update visible rules")
    func addRemoveRuleActions() {
        let appState = makeAppState(name: "addRemoveRuleActions")
        let selectedSet = appState.ruleSets[0]
        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: selectedSet.id
        )
        controller.loadViewIfNeeded()

        let baselineCount = controller.visibleRules.count
        controller.urlField.stringValue = "https://example.com/path"
        controller.handleAddRule()
        #expect(controller.urlField.stringValue.isEmpty)
        #expect(controller.visibleRules.contains("https://example.com/path"))
        #expect(controller.visibleRules.count == baselineCount + 1)

        let insertedIndex = controller.visibleRules.firstIndex(of: "https://example.com/path")
        #expect(insertedIndex != nil)
        controller.rulesTableView.selectRowIndexes(
            IndexSet(integer: insertedIndex ?? 0),
            byExtendingSelection: false
        )
        controller.handleRemoveSelected()
        #expect(!controller.visibleRules.contains("https://example.com/path"))
        #expect(controller.visibleRules.count == baselineCount)
    }

    @MainActor
    @Test("floating editor blocks rule edits when strict mode is on (regardless of focus state)")
    func addRemoveAllowedWhenStrictAndNotBlocking() {
        let appState = makeAppState(name: "addRemoveAllowedWhenStrictAndNotBlocking")
        appState.isStrict = true
        appState.isBlocking = false
        let selectedSet = appState.ruleSets[0]
        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: selectedSet.id
        )
        controller.loadViewIfNeeded()

        let baselineCount = controller.visibleRules.count
        controller.urlField.stringValue = "https://focus-allowed.test"
        controller.handleAddRule()
        #expect(!controller.visibleRules.contains("https://focus-allowed.test"))
        #expect(controller.visibleRules.count == baselineCount)

        if baselineCount > 0 {
            controller.rulesTableView.selectRowIndexes(
                IndexSet(integer: 0),
                byExtendingSelection: false
            )
            let firstRule = controller.visibleRules[0]
            controller.handleRemoveSelected()
            #expect(controller.visibleRules.contains(firstRule))
            #expect(controller.visibleRules.count == baselineCount)
        }
    }

    @MainActor
    @Test("floating editor create/delete list actions follow strict lock rules")
    func createDeleteListActions() {
        let appState = makeAppState(name: "createDeleteListActions")
        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: nil
        )
        controller.loadViewIfNeeded()

        defer { AllowedWebsitesRuleSetAlertPresenter.resetForTesting() }
        AllowedWebsitesRuleSetAlertPresenter.makeAlert = { NSAlert() }
        AllowedWebsitesRuleSetAlertPresenter.runModal = { alert in
            if let input = alert.accessoryView as? NSTextField {
                input.stringValue = "Imported"
            }
            return .alertFirstButtonReturn
        }

        let originalCount = appState.ruleSets.count
        controller.handleCreateRuleSet()
        #expect(appState.ruleSets.count == originalCount + 1)
        let createdId = appState.ruleSets.last?.id
        #expect(createdId != nil)

        controller.selectedRuleSetId = createdId
        controller.handleDeleteRuleSet()
        #expect(appState.ruleSets.count == originalCount)

        // Cover activeRuleSetId fallback path when explicit selection is nil.
        appState.createRuleSet(name: "Extra", makeActive: false)
        controller.selectedRuleSetId = nil
        appState.activeRuleSetId = appState.ruleSets.first?.id
        AllowedWebsitesRuleSetAlertPresenter.runModal = { _ in .alertSecondButtonReturn }
        controller.handleDeleteRuleSet()
        #expect(appState.ruleSets.count == originalCount + 1)

        // Cover first-rule fallback path when both explicit selection and active id are nil.
        appState.activeRuleSetId = nil
        controller.selectedRuleSetId = nil
        controller.handleDeleteRuleSet()
        #expect(appState.ruleSets.count == originalCount + 1)

        appState.isBlocking = true
        appState.isStrict = true
        controller.handleCreateRuleSet()
        #expect(appState.ruleSets.count == originalCount + 1)

        controller.handleDeleteRuleSet()
        #expect(appState.ruleSets.count == originalCount + 1)

        appState.isBlocking = false
        AllowedWebsitesRuleSetAlertPresenter.runModal = { alert in
            (alert.accessoryView as? NSTextField)?.stringValue = "UnlockedInFocus"
            return .alertFirstButtonReturn
        }
        controller.handleCreateRuleSet()
        #expect(appState.ruleSets.count == originalCount + 1)
    }

    @MainActor
    @Test("floating editor action guards cover invalid add/remove/delete and table selection callback")
    func actionGuardBranches() {
        let appState = makeAppState(name: "actionGuardBranches")
        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: nil
        )
        controller.loadViewIfNeeded()

        let baselineCount = controller.visibleRules.count
        controller.urlField.stringValue = "   "
        controller.handleAddRule()
        #expect(controller.visibleRules.count == baselineCount)

        controller.rulesTableView.deselectAll(nil)
        controller.handleRemoveSelected()
        #expect(controller.visibleRules.count == baselineCount)

        // Keep only one list so delete is guard-blocked.
        while appState.ruleSets.count > 1 {
            appState.deleteSet(id: appState.ruleSets.last!.id)
        }
        let singleListCount = appState.ruleSets.count
        controller.handleDeleteRuleSet()
        #expect(appState.ruleSets.count == singleListCount)

        // Cover explicit table-selection callback path.
        let previousRemoveEnabled = controller.removeButton.isEnabled
        controller.handleTableSelectionChange()
        #expect(controller.removeButton.isEnabled == previousRemoveEnabled)

        // Cover add/remove guards when no rule set can be resolved.
        appState.ruleSets = []
        appState.activeRuleSetId = nil
        controller.selectedRuleSetId = nil
        let visibleBeforeNoRuleSetGuards = controller.visibleRules
        controller.urlField.stringValue = "example.com"
        controller.handleAddRule()
        controller.handleRemoveSelected()
        #expect(controller.visibleRules == visibleBeforeNoRuleSetGuards)
    }

    @MainActor
    @Test("floating editor import action covers empty, cancel, and add-selected branches")
    func importOpenTabsActionBranches() {
        let appState = makeAppState(
            name: "importOpenTabsActionBranches",
            openUrls: [
                "https://www.youtube.com/watch?v=abc",
                "https://developer.apple.com/documentation",
            ]
        )
        let setId = appState.ruleSets[0].id
        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: setId
        )
        controller.loadViewIfNeeded()

        defer { AllowedWebsitesFloatingEditorViewController.resetImportPresentersForTesting() }

        let baselineCount = controller.visibleRules.count
        var emptyStateCalls = 0
        AllowedWebsitesFloatingEditorViewController.presentEmptyImportState = { _ in
            emptyStateCalls += 1
        }

        AllowedWebsitesFloatingEditorViewController.presentImportCandidates = { _, _ in nil }
        controller.handleImportOpenTabs()
        #expect(emptyStateCalls == 0)
        #expect(controller.visibleRules.count == baselineCount)

        AllowedWebsitesFloatingEditorViewController.presentImportCandidates = { candidates, _ in
            #expect(!candidates.isEmpty)
            return [candidates[0].rule]
        }
        controller.handleImportOpenTabs()
        #expect(controller.visibleRules.count == baselineCount + 1)

        AllowedWebsitesFloatingEditorViewController.presentImportCandidates = { _, _ in [] }
        controller.handleImportOpenTabs()
        #expect(controller.visibleRules.count == baselineCount + 1)

        let emptyState = makeAppState(name: "importOpenTabsEmpty", openUrls: [])
        let emptyController = AllowedWebsitesFloatingEditorViewController(
            appState: emptyState,
            initialRuleSetId: emptyState.ruleSets[0].id
        )
        emptyController.loadViewIfNeeded()
        AllowedWebsitesFloatingEditorViewController.presentEmptyImportState = { _ in
            emptyStateCalls += 1
        }
        emptyController.handleImportOpenTabs()
        #expect(emptyStateCalls == 1)
    }

    @MainActor
    @Test("floating editor import guard returns when selected rule-set id is missing")
    func importMissingSelectedRuleSetGuard() {
        let appState = makeAppState(
            name: "importMissingSelectedRuleSetGuard",
            openUrls: ["https://example.com"]
        )
        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: UUID()
        )
        controller.loadViewIfNeeded()
        appState.ruleSets = []
        appState.activeRuleSetId = nil
        controller.selectedRuleSetId = nil

        var candidatesPresenterCalls = 0
        defer { AllowedWebsitesFloatingEditorViewController.resetImportPresentersForTesting() }
        AllowedWebsitesFloatingEditorViewController.presentImportCandidates = { _, _ in
            candidatesPresenterCalls += 1
            return nil
        }

        controller.handleImportOpenTabs()
        #expect(candidatesPresenterCalls == 0)
    }

    @MainActor
    @Test("floating editor import calls presenter before checking strict lock; returning nil blocks add")
    func importLockedWhenStrictEditingLockIsActive() {
        let appState = makeAppState(
            name: "importLockedWhenStrictEditingLockIsActive",
            openUrls: ["https://example.com"]
        )
        appState.isStrict = true
        appState.isBlocking = true
        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: appState.ruleSets.first?.id
        )
        controller.loadViewIfNeeded()

        var presenterCalls = 0
        defer { AllowedWebsitesFloatingEditorViewController.resetImportPresentersForTesting() }
        AllowedWebsitesFloatingEditorViewController.presentImportCandidates = { _, _ in
            presenterCalls += 1
            return nil
        }

        controller.handleImportOpenTabs()
        #expect(presenterCalls == 1)
    }

    @MainActor
    @Test("floating editor add/remove rule actions are locked while strict mode is active with focus on")
    func addRemoveLockedWhenStrictEditingLockIsActive() {
        let appState = makeAppState(name: "addRemoveLockedWhenStrictEditingLockIsActive")
        appState.isStrict = true
        appState.isBlocking = true
        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: appState.ruleSets.first?.id
        )
        controller.loadViewIfNeeded()

        let baselineRules = controller.visibleRules
        controller.urlField.stringValue = "https://locked.example.com"
        controller.handleAddRule()
        #expect(controller.visibleRules == baselineRules)

        controller.rulesTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        controller.handleRemoveSelected()
        #expect(controller.visibleRules == baselineRules)
    }

    @MainActor
    @Test("floating editor styling toggles strict-mode warning constraints and header icons")
    func layoutStylingStrictWarningBranches() {
        let appState = makeAppState(name: "layoutStylingStrictWarningBranches")
        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: appState.ruleSets.first?.id
        )
        controller.loadViewIfNeeded()

        appState.isStrict = false
        appState.isBlocking = false
        controller.applyButtonStyling()
        #expect(controller.strictModeWarningLabel.isHidden == true)
        #expect(controller.warningCollapsedHeightConstraint?.isActive == true)
        #expect(controller.warningTopConstraint?.constant == 0)

        appState.isStrict = true
        appState.isBlocking = true
        controller.applyButtonStyling()
        #expect(controller.strictModeWarningLabel.isHidden == false)
        #expect(controller.warningCollapsedHeightConstraint?.isActive == false)
        #expect(controller.warningTopConstraint?.constant == 8)
        #expect(controller.createListButton.image != nil)
        #expect(controller.deleteListButton.image != nil)
    }

    @MainActor
    @Test("floating editor row tap callback safely no-ops after controller deallocation")
    func rowTapCallbackWeakSelfNoOpAfterDeallocation() {
        let appState = makeAppState(name: "rowTapCallbackWeakSelfNoOpAfterDeallocation")
        let beforeActive = appState.activeRuleSetId

        var retainedRowButton: AppKitSelectableRowButton?
        weak var weakController: AllowedWebsitesFloatingEditorViewController?

        do {
            var controller: AllowedWebsitesFloatingEditorViewController? =
                AllowedWebsitesFloatingEditorViewController(
                    appState: appState,
                    initialRuleSetId: appState.ruleSets.first?.id
                )
            controller?.loadViewIfNeeded()
            retainedRowButton = controller?.ruleSetButtons.values.first
            weakController = controller
            controller = nil
        }

        #expect(weakController == nil)
        retainedRowButton?.performClick(nil)
        #expect(appState.activeRuleSetId == beforeActive)
    }

    @MainActor
    @Test("import alert presenter covers empty-state and candidate-selection paths")
    func importAlertPresenterBranches() {
        defer { AllowedWebsitesImportAlertPresenter.resetForTesting() }
        AllowedWebsitesImportAlertPresenter.makeAlert = { NSAlert() }

        var emptyStateRan = false
        AllowedWebsitesImportAlertPresenter.runModal = { alert in
            emptyStateRan = true
            #expect(alert.messageText == "Import Open Tabs")
            #expect(alert.buttons.count == 1)
            return .alertSecondButtonReturn
        }
        AllowedWebsitesImportAlertPresenter.presentEmptyState(currentOpenUrls: [])
        #expect(emptyStateRan)

        let candidates: [AllowedWebsitesImportCoordinator.Candidate] = [
            .init(
                rule: "example.com",
                title: "example.com",
                isSelectable: true,
                defaultSelected: true
            ),
            .init(
                rule: "already.com",
                title: "already allowed",
                isSelectable: false,
                defaultSelected: false
            ),
        ]

        AllowedWebsitesImportAlertPresenter.runModal = { alert in
            #expect(alert.buttons.count == 2)
            let accessory = alert.accessoryView
            #expect(accessory != nil)
            let container = accessory?.subviews.first(where: { $0 is NSButton })?.superview
            let selectAll = container?.subviews.compactMap { $0 as? NSButton }.first(where: {
                $0.title == "Select all"
            })
            #expect(selectAll != nil)
            selectAll?.state = .off
            _ = selectAll?.target?.perform(selectAll?.action, with: selectAll)
            return .alertFirstButtonReturn
        }

        let selected = AllowedWebsitesImportAlertPresenter.presentCandidateSelection(
            candidates: candidates,
            selectedSetName: "Main"
        )
        #expect(selected?.isEmpty == true)
    }

    @MainActor
    @Test("rule-set alert presenter covers create/cancel and delete confirmation branches")
    func ruleSetAlertPresenterBranches() {
        defer { AllowedWebsitesRuleSetAlertPresenter.resetForTesting() }
        AllowedWebsitesRuleSetAlertPresenter.makeAlert = { NSAlert() }

        AllowedWebsitesRuleSetAlertPresenter.runModal = { alert in
            if let input = alert.accessoryView as? NSTextField {
                input.stringValue = "Team"
            }
            return .alertFirstButtonReturn
        }
        let createdName = AllowedWebsitesRuleSetAlertPresenter.promptForNewRuleSetName()
        #expect(createdName == "Team")

        AllowedWebsitesRuleSetAlertPresenter.runModal = { _ in .alertSecondButtonReturn }
        #expect(AllowedWebsitesRuleSetAlertPresenter.promptForNewRuleSetName() == nil)
        #expect(AllowedWebsitesRuleSetAlertPresenter.confirmDeleteRuleSet(named: "Team") == false)

        var nativeModalUsed = false
        AllowedWebsitesRuleSetAlertPresenter.environmentProvider = { [:] }
        AllowedWebsitesRuleSetAlertPresenter.classLookup = { _ in nil }
        AllowedWebsitesRuleSetAlertPresenter.runNativeModal = { _ in
            nativeModalUsed = true
            return .alertFirstButtonReturn
        }
        AllowedWebsitesRuleSetAlertPresenter.runModal = { alert in
            AllowedWebsitesRuleSetAlertPresenter.runNativeModal(alert)
        }
        #expect(AllowedWebsitesRuleSetAlertPresenter.confirmDeleteRuleSet(named: "Team"))
        #expect(nativeModalUsed)
    }

    @Test("rules table controller returns rows and builds reusable cell views")
    func rulesTableControllerBranches() {
        let controller = AllowedWebsitesRulesTableController()
        controller.numberOfRules = { 2 }
        controller.ruleAt = { index in
            switch index {
            case 0: "a.com"
            case 1: "b.com"
            default: nil
            }
        }

        let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 320, height: 120))
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AllowedRule")))

        #expect(controller.numberOfRows(in: table) == 2)
        let first = controller.tableView(table, viewFor: table.tableColumns.first, row: 0) as? NSTableCellView
        #expect(first?.textField?.stringValue == "a.com")
        let second = controller.tableView(table, viewFor: table.tableColumns.first, row: 1) as? NSTableCellView
        #expect(second?.textField?.stringValue == "b.com")
        let outOfBounds = controller.tableView(
            table,
            viewFor: table.tableColumns.first,
            row: 3
        ) as? NSTableCellView
        #expect(outOfBounds?.textField?.stringValue == "")

        let rowView = controller.tableView(table, rowViewForRow: 0)
        #expect(rowView != nil)
        rowView?.selectionHighlightStyle = .none
        rowView?.drawSelection(in: rowView?.bounds ?? .zero)
        rowView?.selectionHighlightStyle = .regular
        rowView?.drawSelection(in: rowView?.bounds ?? .zero)
    }
}
