import AppKit
import Foundation
import Testing

@testable import FreeLogic

private final class ImportCoverageAutomator: BrowserAutomator {
    var openUrls: [String]

    init(openUrls: [String]) {
        self.openUrls = openUrls
    }

    func getActiveUrl(for app: NSRunningApplication) -> String? { nil }
    func redirect(app: NSRunningApplication, to url: String) {}
    func getAllOpenUrls(browsers: [String]) -> [String] { openUrls }
    func checkPermissions(prompt: Bool) -> Bool { true }
}

@Suite(.serialized)
struct ModalAndShellCoverageTests {
    private final class NonBlockingAlert: NSAlert {
        override func runModal() -> NSApplication.ModalResponse {
            .alertFirstButtonReturn
        }
    }

    private func isolatedAppState(
        name: String,
        openUrls: [String] = []
    ) -> AppState {
        let suite = "ModalAndShellCoverageTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let monitor = BrowserMonitor(
            stateSnapshotProvider: { nil },
            onEvent: { _ in },
            server: nil,
            automator: ImportCoverageAutomator(openUrls: openUrls),
            startTimer: false
        )
        return AppState(defaults: defaults, monitor: monitor, calendar: MockCalendarManager(), isTesting: true)
    }

    private func findButton(titled title: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == title {
            return button
        }
        for subview in view.subviews {
            if let found = findButton(titled: title, in: subview) { return found }
        }
        return nil
    }

    private func mirrorValue<T>(named name: String, in object: Any) -> T? {
        Mirror(reflecting: object).children.first(where: { $0.label == name })?.value as? T
    }

    @Test("Schedule editor action coordinator maps popup index and recurring toggle")
    func scheduleEditorActionCoordinator() {
        let ids = [UUID(), UUID()]
        let sets = [
            RuleSet(id: ids[0], name: "A", urls: []),
            RuleSet(id: ids[1], name: "B", urls: []),
        ]

        #expect(ScheduleEditorActionsCoordinator.ruleSetIdForSelectedPopupIndex(0, ruleSets: sets) == nil)
        #expect(ScheduleEditorActionsCoordinator.ruleSetIdForSelectedPopupIndex(1, ruleSets: sets) == ids[0])
        #expect(ScheduleEditorActionsCoordinator.ruleSetIdForSelectedPopupIndex(2, ruleSets: sets) == ids[1])
        #expect(ScheduleEditorActionsCoordinator.ruleSetIdForSelectedPopupIndex(4, ruleSets: sets) == nil)

        #expect(ScheduleEditorActionsCoordinator.toggledRecurring(checkboxState: .on))
        #expect(ScheduleEditorActionsCoordinator.toggledRecurring(checkboxState: .off) == false)
    }

    @MainActor
    @Test("Rule-set alert presenters default native-modal runners execute through NSAlert.runModal override")
    func alertPresentersDefaultNativeModalRunners() {
        defer {
            AllowedWebsitesRuleSetAlertPresenter.resetForTesting()
            RulesSheetAlertPresenter.resetForTesting()
            AllowedWebsitesImportAlertPresenter.resetForTesting()
        }

        AllowedWebsitesRuleSetAlertPresenter.resetForTesting()
        AllowedWebsitesRuleSetAlertPresenter.environmentProvider = { [:] }
        AllowedWebsitesRuleSetAlertPresenter.classLookup = { _ in nil }
        _ = AllowedWebsitesRuleSetAlertPresenter.makeAlert()
        #expect(AllowedWebsitesRuleSetAlertPresenter.runModal(NonBlockingAlert()) == .alertFirstButtonReturn)

        RulesSheetAlertPresenter.resetForTesting()
        RulesSheetAlertPresenter.environmentProvider = { [:] }
        RulesSheetAlertPresenter.classLookup = { _ in nil }
        _ = RulesSheetAlertPresenter.makeAlert()
        #expect(RulesSheetAlertPresenter.runModal(NonBlockingAlert()) == .alertFirstButtonReturn)

        AllowedWebsitesImportAlertPresenter.resetForTesting()
        AllowedWebsitesImportAlertPresenter.environmentProvider = { [:] }
        AllowedWebsitesImportAlertPresenter.classLookup = { _ in nil }
        _ = AllowedWebsitesImportAlertPresenter.makeAlert()
        #expect(AllowedWebsitesImportAlertPresenter.runNativeModal(NonBlockingAlert()) == .alertFirstButtonReturn)
        #expect(AllowedWebsitesImportAlertPresenter.runModal(NonBlockingAlert()) == .alertFirstButtonReturn)
    }

    @MainActor
    @Test("Alert presenters support create/cancel and confirm paths through injected runner")
    func alertPresenters() {
        defer {
            AllowedWebsitesRuleSetAlertPresenter.resetForTesting()
            RulesSheetAlertPresenter.resetForTesting()
            AllowedWebsitesImportAlertPresenter.resetForTesting()
        }

        // Cover default factories/runners (test runtime returns non-blocking response).
        AllowedWebsitesRuleSetAlertPresenter.resetForTesting()
        _ = AllowedWebsitesRuleSetAlertPresenter.makeAlert()
        _ = AllowedWebsitesRuleSetAlertPresenter.runModal(NSAlert())
        RulesSheetAlertPresenter.resetForTesting()
        _ = RulesSheetAlertPresenter.makeAlert()
        _ = RulesSheetAlertPresenter.runModal(NSAlert())
        AllowedWebsitesImportAlertPresenter.resetForTesting()
        _ = AllowedWebsitesImportAlertPresenter.makeAlert()
        _ = AllowedWebsitesImportAlertPresenter.runModal(NSAlert())
        var usedImportNativeRunner = false
        AllowedWebsitesImportAlertPresenter.environmentProvider = { ["XCTestConfigurationFilePath": "1"] }
        AllowedWebsitesImportAlertPresenter.classLookup = { _ in nil }
        #expect(AllowedWebsitesImportAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        AllowedWebsitesImportAlertPresenter.environmentProvider = { ["XCTestBundlePath": "1"] }
        #expect(AllowedWebsitesImportAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        AllowedWebsitesImportAlertPresenter.environmentProvider = {
            ["SWIFT_TESTING_ENABLE_EXPERIMENTAL_FEATURES": "1"]
        }
        #expect(AllowedWebsitesImportAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        AllowedWebsitesImportAlertPresenter.environmentProvider = { ["__XCODE_BUILT_PRODUCTS_DIR_PATHS": "1"] }
        #expect(AllowedWebsitesImportAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        AllowedWebsitesImportAlertPresenter.environmentProvider = { [:] }
        AllowedWebsitesImportAlertPresenter.classLookup = { _ in nil }
        AllowedWebsitesImportAlertPresenter.runNativeModal = { _ in
            usedImportNativeRunner = true
            return .alertFirstButtonReturn
        }
        #expect(AllowedWebsitesImportAlertPresenter.runModal(NSAlert()) == .alertFirstButtonReturn)
        #expect(usedImportNativeRunner)
        AllowedWebsitesImportAlertPresenter.classLookup = { _ in NSObject.self }
        #expect(AllowedWebsitesImportAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)

        var usedAllowedNativeRunner = false
        AllowedWebsitesRuleSetAlertPresenter.environmentProvider = { ["XCTestConfigurationFilePath": "1"] }
        AllowedWebsitesRuleSetAlertPresenter.classLookup = { _ in nil }
        #expect(AllowedWebsitesRuleSetAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        AllowedWebsitesRuleSetAlertPresenter.environmentProvider = { ["XCTestBundlePath": "1"] }
        #expect(AllowedWebsitesRuleSetAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        AllowedWebsitesRuleSetAlertPresenter.environmentProvider = {
            ["SWIFT_TESTING_ENABLE_EXPERIMENTAL_FEATURES": "1"]
        }
        #expect(AllowedWebsitesRuleSetAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        AllowedWebsitesRuleSetAlertPresenter.environmentProvider = { ["__XCODE_BUILT_PRODUCTS_DIR_PATHS": "1"] }
        AllowedWebsitesRuleSetAlertPresenter.classLookup = { _ in nil }
        #expect(AllowedWebsitesRuleSetAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        AllowedWebsitesRuleSetAlertPresenter.environmentProvider = { [:] }
        AllowedWebsitesRuleSetAlertPresenter.classLookup = { _ in nil }
        AllowedWebsitesRuleSetAlertPresenter.runNativeModal = { _ in
            usedAllowedNativeRunner = true
            return .alertFirstButtonReturn
        }
        #expect(AllowedWebsitesRuleSetAlertPresenter.runModal(NSAlert()) == .alertFirstButtonReturn)
        #expect(usedAllowedNativeRunner)
        AllowedWebsitesRuleSetAlertPresenter.classLookup = { _ in NSObject.self }
        #expect(AllowedWebsitesRuleSetAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)

        var usedRulesNativeRunner = false
        RulesSheetAlertPresenter.environmentProvider = { ["XCTestConfigurationFilePath": "1"] }
        RulesSheetAlertPresenter.classLookup = { _ in nil }
        #expect(RulesSheetAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        RulesSheetAlertPresenter.environmentProvider = { ["XCTestBundlePath": "1"] }
        #expect(RulesSheetAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        RulesSheetAlertPresenter.environmentProvider = {
            ["SWIFT_TESTING_ENABLE_EXPERIMENTAL_FEATURES": "1"]
        }
        #expect(RulesSheetAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        RulesSheetAlertPresenter.environmentProvider = { ["__XCODE_BUILT_PRODUCTS_DIR_PATHS": "1"] }
        RulesSheetAlertPresenter.classLookup = { _ in nil }
        #expect(RulesSheetAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)
        RulesSheetAlertPresenter.environmentProvider = { [:] }
        RulesSheetAlertPresenter.classLookup = { _ in nil }
        RulesSheetAlertPresenter.runNativeModal = { _ in
            usedRulesNativeRunner = true
            return .alertFirstButtonReturn
        }
        #expect(RulesSheetAlertPresenter.runModal(NSAlert()) == .alertFirstButtonReturn)
        #expect(usedRulesNativeRunner)
        RulesSheetAlertPresenter.classLookup = { _ in NSObject.self }
        #expect(RulesSheetAlertPresenter.runModal(NSAlert()) == .alertSecondButtonReturn)

        AllowedWebsitesRuleSetAlertPresenter.makeAlert = { NSAlert() }
        AllowedWebsitesRuleSetAlertPresenter.runModal = { alert in
            (alert.accessoryView as? NSTextField)?.stringValue = "Work"
            return .alertFirstButtonReturn
        }
        #expect(AllowedWebsitesRuleSetAlertPresenter.promptForNewRuleSetName() == "Work")
        AllowedWebsitesRuleSetAlertPresenter.runModal = { _ in .alertSecondButtonReturn }
        #expect(AllowedWebsitesRuleSetAlertPresenter.promptForNewRuleSetName() == nil)

        AllowedWebsitesRuleSetAlertPresenter.runModal = { _ in .alertFirstButtonReturn }
        #expect(AllowedWebsitesRuleSetAlertPresenter.confirmDeleteRuleSet(named: "Work"))
        AllowedWebsitesRuleSetAlertPresenter.runModal = { _ in .alertSecondButtonReturn }
        #expect(AllowedWebsitesRuleSetAlertPresenter.confirmDeleteRuleSet(named: "Work") == false)

        RulesSheetAlertPresenter.makeAlert = { NSAlert() }
        RulesSheetAlertPresenter.runModal = { alert in
            (alert.accessoryView as? NSTextField)?.stringValue = "Set X"
            return .alertFirstButtonReturn
        }
        #expect(RulesSheetAlertPresenter.promptForNewRuleSetName() == "Set X")
        RulesSheetAlertPresenter.runModal = { _ in .alertSecondButtonReturn }
        #expect(RulesSheetAlertPresenter.promptForNewRuleSetName() == nil)

        var emptyPresented = false
        AllowedWebsitesImportAlertPresenter.makeAlert = { NSAlert() }
        AllowedWebsitesImportAlertPresenter.runModal = { _ in
            emptyPresented = true
            return .alertFirstButtonReturn
        }
        AllowedWebsitesImportAlertPresenter.presentEmptyState(currentOpenUrls: [])
        #expect(emptyPresented)

        let candidates = [
            AllowedWebsitesImportCoordinator.Candidate(
                rule: "https://example.com",
                title: "https://example.com",
                isSelectable: true,
                defaultSelected: true
            ),
            AllowedWebsitesImportCoordinator.Candidate(
                rule: "https://toggle-on.com",
                title: "https://toggle-on.com",
                isSelectable: true,
                defaultSelected: false
            ),
            AllowedWebsitesImportCoordinator.Candidate(
                rule: "https://already.com",
                title: "https://already.com (already allowed)",
                isSelectable: false,
                defaultSelected: false
            ),
        ]
        AllowedWebsitesImportAlertPresenter.runModal = { _ in .alertFirstButtonReturn }
        #expect(
            AllowedWebsitesImportAlertPresenter.presentCandidateSelection(
                candidates: candidates,
                selectedSetName: "Work"
            ) == ["https://example.com"]
        )

        AllowedWebsitesImportAlertPresenter.runModal = { alert in
            guard
                let accessory = alert.accessoryView,
                let selectAll = accessory.subviews.compactMap({ $0 as? NSButton }).first
            else {
                return .alertFirstButtonReturn
            }
            selectAll.state = .off
            if let action = selectAll.action {
                _ = NSApp.sendAction(action, to: selectAll.target, from: selectAll)
            }
            return .alertFirstButtonReturn
        }
        #expect(
            AllowedWebsitesImportAlertPresenter.presentCandidateSelection(
                candidates: candidates,
                selectedSetName: "Work"
            ) == []
        )

        AllowedWebsitesImportAlertPresenter.runModal = { alert in
            guard
                let accessory = alert.accessoryView,
                let selectAll = accessory.subviews.compactMap({ $0 as? NSButton }).first
            else {
                return .alertFirstButtonReturn
            }
            selectAll.state = .on
            if let action = selectAll.action {
                _ = NSApp.sendAction(action, to: selectAll.target, from: selectAll)
            }
            return .alertFirstButtonReturn
        }
        #expect(
            AllowedWebsitesImportAlertPresenter.presentCandidateSelection(
                candidates: candidates,
                selectedSetName: "Work"
            )?.sorted() == ["https://example.com", "https://toggle-on.com"]
        )

        AllowedWebsitesImportAlertPresenter.runModal = { _ in .alertSecondButtonReturn }
        #expect(
            AllowedWebsitesImportAlertPresenter.presentCandidateSelection(
                candidates: candidates,
                selectedSetName: "Work"
            ) == nil
        )
    }

    @MainActor
    @Test("Allowed websites import action uses injected presenter callbacks")
    func allowedWebsitesImportActionFlow() async {
        let appState = isolatedAppState(
            name: "allowedWebsitesImportActionFlow",
            openUrls: ["https://swift.org", "https://example.com"]
        )
        let ruleSet = RuleSet(name: "Default", urls: ["https://swift.org"])
        appState.ruleSets = [ruleSet]
        appState.activeRuleSetId = ruleSet.id

        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: ruleSet.id
        )
        controller.loadViewIfNeeded()
        controller.viewDidLoad()

        defer {
            AllowedWebsitesFloatingEditorViewController.resetImportPresentersForTesting()
        }

        var didPresentEmpty = false
        AllowedWebsitesFloatingEditorViewController.presentEmptyImportState = { _ in
            didPresentEmpty = true
        }
        AllowedWebsitesFloatingEditorViewController.presentImportCandidates = { candidates, _ in
            #expect(candidates.count >= 1)
            return ["https://example.com"]
        }

        await controller.handleImportOpenTabsAsync()
        #expect(didPresentEmpty == false)
        #expect(appState.ruleSets.first?.urls.contains("https://example.com") == true)
    }

    @MainActor
    @Test("Allowed websites editor actions cover create/delete/import guard branches")
    func allowedWebsitesEditorActionBranches() async {
        let appState = isolatedAppState(
            name: "allowedWebsitesEditorActionBranches",
            openUrls: []
        )
        let defaultSet = RuleSet(name: "Default", urls: [])
        appState.ruleSets = [defaultSet]
        appState.activeRuleSetId = defaultSet.id

        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: defaultSet.id
        )
        controller.loadViewIfNeeded()
        controller.viewDidLoad()

        defer {
            AllowedWebsitesRuleSetAlertPresenter.resetForTesting()
            AllowedWebsitesFloatingEditorViewController.resetImportPresentersForTesting()
        }

        appState.isStrict = true
        appState.isBlocking = true
        controller.handleCreateRuleSet()
        #expect(appState.ruleSets.count == 1)

        appState.isStrict = false
        appState.isBlocking = false
        AllowedWebsitesRuleSetAlertPresenter.makeAlert = { NSAlert() }
        AllowedWebsitesRuleSetAlertPresenter.runModal = { alert in
            (alert.accessoryView as? NSTextField)?.stringValue = "Work"
            return .alertFirstButtonReturn
        }
        controller.handleCreateRuleSet()
        #expect(appState.ruleSets.count == 2)

        let toDeleteId = appState.ruleSets.first(where: { $0.name == "Work" })?.id
        #expect(toDeleteId != nil)
        controller.selectedRuleSetId = toDeleteId

        AllowedWebsitesRuleSetAlertPresenter.runModal = { _ in .alertSecondButtonReturn }
        controller.handleDeleteRuleSet()
        #expect(appState.ruleSets.contains(where: { $0.id == toDeleteId }) == true)

        AllowedWebsitesRuleSetAlertPresenter.runModal = { _ in .alertFirstButtonReturn }
        controller.handleDeleteRuleSet()
        #expect(appState.ruleSets.contains(where: { $0.id == toDeleteId }) == false)

        var showedEmptyImportState = false
        AllowedWebsitesFloatingEditorViewController.presentEmptyImportState = { _ in
            showedEmptyImportState = true
        }
        controller.selectedRuleSetId = appState.ruleSets.first?.id
        await controller.handleImportOpenTabsAsync()
        #expect(showedEmptyImportState)

        // Cover default import presenter closures in the controller extension.
        AllowedWebsitesFloatingEditorViewController.resetImportPresentersForTesting()
        AllowedWebsitesImportAlertPresenter.resetForTesting()
        AllowedWebsitesFloatingEditorViewController.presentEmptyImportState([])
        _ = AllowedWebsitesFloatingEditorViewController.presentImportCandidates([], "Any")
    }

    @MainActor
    @Test("Allowed websites editor action controller covers row taps, strict lock, and add/remove guards")
    func allowedWebsitesEditorActionControllerPaths() {
        let appState = isolatedAppState(
            name: "allowedWebsitesEditorActionControllerPaths",
            openUrls: ["https://swift.org"]
        )
        let setA = RuleSet(name: "A", urls: ["a.com"])
        let setB = RuleSet(name: "B", urls: ["b.com"])
        appState.ruleSets = [setA, setB]
        appState.activeRuleSetId = setA.id

        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: setB.id
        )
        controller.loadViewIfNeeded()
        controller.viewDidLoad()

        defer {
            AllowedWebsitesRuleSetAlertPresenter.resetForTesting()
        }

        controller.reloadRuleSetRows()
        #expect(controller.selectedRuleSetId == setB.id)
        controller.ruleSetButtons[setA.id]?.performClick(nil)
        #expect(controller.selectedRuleSetId == setA.id)

        appState.isBlocking = true
        appState.isStrict = true
        controller.selectedRuleSetId = setA.id
        controller.reloadRuleSetRows()
        controller.ruleSetButtons[setB.id]?.performClick(nil)
        #expect(controller.selectedRuleSetId == setA.id)

        appState.isStrict = false
        appState.isBlocking = false

        AllowedWebsitesRuleSetAlertPresenter.makeAlert = { NSAlert() }
        AllowedWebsitesRuleSetAlertPresenter.runModal = { _ in .alertSecondButtonReturn }
        let initialCount = appState.ruleSets.count
        controller.handleCreateRuleSet()
        #expect(appState.ruleSets.count == initialCount)

        AllowedWebsitesRuleSetAlertPresenter.runModal = { alert in
            (alert.accessoryView as? NSTextField)?.stringValue = "Created"
            return .alertFirstButtonReturn
        }
        controller.handleCreateRuleSet()
        #expect(appState.ruleSets.contains(where: { $0.name == "Created" }))

        controller.selectedRuleSetId = UUID() // unresolved/missing selected set branch
        AllowedWebsitesRuleSetAlertPresenter.runModal = { _ in .alertFirstButtonReturn }
        controller.handleDeleteRuleSet()

        controller.urlField.stringValue = "   "
        let beforeRules = appState.ruleSets
        controller.handleAddRule()
        #expect(appState.ruleSets == beforeRules)

        let targetRuleSetId = controller.resolvedRuleSetId(setA.id)
            ?? appState.ruleSets.first?.id
        #expect(targetRuleSetId != nil)
        controller.selectedRuleSetId = targetRuleSetId
        controller.urlField.stringValue = "new.com"
        controller.handleAddRule()
        #expect(
            appState.ruleSets
                .first(where: { $0.id == targetRuleSetId })?
                .urls
                .contains("new.com") == true
        )
        #expect(controller.urlField.stringValue.isEmpty)

        controller.reloadRulesOnly()
        if let index = controller.visibleRules.firstIndex(of: "new.com") {
            controller.rulesTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            controller.handleRemoveSelected()
            #expect(controller.visibleRules.contains("new.com") == false)
        } else {
            Issue.record("Expected added rule to be visible for removal path")
        }

        controller.rulesTableView.deselectAll(nil)
        controller.handleRemoveSelected()
        controller.handleTableSelectionChange()
    }

    @MainActor
    @Test("Allowed websites editor covers weak-self closures, add-from-field, and preserved selection")
    func allowedWebsitesEditorClosureAndSelectionCoverage() {
        let appState = isolatedAppState(name: "allowedWebsitesEditorClosureAndSelectionCoverage")
        let set = RuleSet(name: "Default", urls: ["https://swift.org", "https://example.com"])
        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id

        var countProvider: (() -> Int)?
        var ruleProvider: ((Int) -> String?)?
        weak var weakController: AllowedWebsitesFloatingEditorViewController?

        do {
            let controller = AllowedWebsitesFloatingEditorViewController(
                appState: appState,
                initialRuleSetId: set.id
            )
            weakController = controller
            controller.loadViewIfNeeded()
            controller.viewDidLoad()
            controller.focusOnRuleSet(set.id)

            #expect(controller.rulesTableController.numberOfRows(in: controller.rulesTableView) == 2)
            #expect(controller.rulesTableController.ruleAt(0) == "https://swift.org")
            #expect(controller.rulesTableController.ruleAt(99) == nil)

            controller.rulesTableView.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
            controller.reloadRulesOnly()
            #expect(controller.rulesTableView.selectedRow == 1)

            controller.urlField.stringValue = "new.example"
            controller.handleAddRuleFromField(controller.urlField)
            #expect(controller.visibleRules.contains("new.example"))

            countProvider = controller.rulesTableController.numberOfRules
            ruleProvider = controller.rulesTableController.ruleAt
        }

        #expect(weakController == nil)
        #expect(countProvider?() == 0)
        #expect(ruleProvider?(0) == nil)
    }

    @MainActor
    @Test("Import support covers default presenters and unresolved-set guard")
    func allowedWebsitesImportSupportBranches() async {
        let appState = isolatedAppState(name: "allowedWebsitesImportSupportBranches")
        appState.ruleSets = []
        appState.activeRuleSetId = nil

        let controller = AllowedWebsitesFloatingEditorViewController(appState: appState, initialRuleSetId: nil)
        controller.loadViewIfNeeded()
        controller.viewDidLoad()

        // No selected set path.
        await controller.handleImportOpenTabsAsync()

        // Exercise default static presenter closures.
        AllowedWebsitesFloatingEditorViewController.resetImportPresentersForTesting()
        AllowedWebsitesImportAlertPresenter.resetForTesting()
        AllowedWebsitesFloatingEditorViewController.presentEmptyImportState([])
        _ = AllowedWebsitesFloatingEditorViewController.presentImportCandidates([], "Default")
    }

    @MainActor
    @Test("Import presenter static defaults and observation-driven reload execute")
    func allowedWebsitesImportDefaultsAndObservationReload() {
        // Execute static default closure initializers before any reset.
        _ = AllowedWebsitesFloatingEditorViewController.presentImportCandidates([], "Default")
        AllowedWebsitesFloatingEditorViewController.presentEmptyImportState([])

        let appState = isolatedAppState(name: "allowedWebsitesImportDefaultsAndObservationReload")
        let initial = RuleSet(name: "Initial", urls: [])
        appState.ruleSets = [initial]
        appState.activeRuleSetId = initial.id

        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: initial.id
        )
        controller.loadViewIfNeeded()
        controller.viewDidLoad()

        controller.selectedRuleSetId = UUID()
        appState.ruleSets = [initial, RuleSet(name: "Second", urls: [])]

        let limit = Date().addingTimeInterval(0.5)
        while Date() < limit {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        #expect(controller.selectedRuleSetId == initial.id)
    }

    @MainActor
    @Test("Free sheet container wires done action and hosted content")
    func freeSheetContainer() {
        let hosted = NSViewController()
        hosted.view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        var doneCount = 0
        let container = FreeSheetContainerViewController(
            title: "Rules",
            contentController: hosted
        ) {
            doneCount += 1
        }
        container.loadViewIfNeeded()

        #expect(container.children.contains(hosted))
        #expect(container.view.subviews.count >= 4)

        let doneButton = findButton(titled: "Done", in: container.view)
        #expect(doneButton != nil)
        doneButton?.performClick(nil)
        #expect(doneCount == 1)
    }

    @MainActor
    @Test("Free sheet window controller supports panel and sheet presentation modes")
    func freeSheetWindowController() {
        let parent = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        var floatingClosed = 0
        let floating = FreeSheetWindowController(
            contentViewController: NSViewController(),
            contentSize: CGSize(width: 400, height: 320),
            presentsAsSheet: false,
            showsNativeCloseButton: true,
            nativeCloseButtonSize: 18,
            nativeCloseButtonXOffset: 2
        ) {
            floatingClosed += 1
        }
        floating.present(for: parent)
        if let window = floating.window {
            window.setFrame(
                NSRect(origin: window.frame.origin, size: NSSize(width: 700, height: 500)),
                display: false
            )
            floating.restoreDesiredContentSize()
            window.setFrame(
                NSRect(origin: window.frame.origin, size: NSSize(width: 760, height: 560)),
                display: false
            )
            floating.reconcileWindowFrameForTesting()
        }
        floating.restoreDesiredContentSize()
        floating.dismiss()
        #expect(floatingClosed == 1)

        var sheetClosed = 0
        let sheet = FreeSheetWindowController(
            contentViewController: NSViewController(),
            contentSize: CGSize(width: 420, height: 300),
            presentsAsSheet: true
        ) {
            sheetClosed += 1
        }
        sheet.present(for: parent)
        sheet.dismiss()
        #expect(sheetClosed == 1)

        sheet.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        #expect(sheetClosed == 2)
    }

    @MainActor
    @Test("Free sheet window controller covers no-op and already-attached branches")
    func freeSheetWindowControllerBranchCoverage() {
        let parent = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // Cover floating dismiss path when not parented.
        var floatingClosed = 0
        let floating = FreeSheetWindowController(
            contentViewController: NSViewController(),
            contentSize: CGSize(width: 360, height: 260),
            presentsAsSheet: false,
            showsNativeCloseButton: false
        ) {
            floatingClosed += 1
        }

        floating.dismiss()
        #expect(floatingClosed == 1)

        guard let floatingWindow = floating.window else {
            Issue.record("Expected floating window")
            return
        }

        // First present attaches and centers.
        floating.present(for: parent)
        #expect(floatingWindow.parent === parent)

        // Second present should cover already-visible / already-parented branches.
        floating.present(for: parent)
        #expect(floatingWindow.parent === parent)

        // Exercise reconcile() branch where width already matches but height differs.
        let targetFrame = floatingWindow.frameRect(
            forContentRect: NSRect(origin: .zero, size: CGSize(width: 360, height: 260))
        )
        floatingWindow.setFrame(
            NSRect(
                origin: floatingWindow.frame.origin,
                size: NSSize(width: targetFrame.width, height: targetFrame.height + 12)
            ),
            display: false
        )
        floating.reconcileWindowFrameForTesting()
        #expect(abs(floatingWindow.frame.height - targetFrame.height) <= 0.5)

        floating.dismiss()
        #expect(floatingClosed == 2)

        // Cover sheet dismiss path when no sheet parent exists.
        var sheetClosed = 0
        let sheet = FreeSheetWindowController(
            contentViewController: NSViewController(),
            contentSize: CGSize(width: 360, height: 260),
            presentsAsSheet: true
        ) {
            sheetClosed += 1
        }
        sheet.dismiss()
        #expect(sheetClosed == 1)
    }

    @MainActor
    @Test("Free sheet window controller guard-return branches are covered")
    func freeSheetWindowControllerGuardBranches() {
        let parent = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        var closeCount = 0
        let controller = FreeSheetWindowController(
            contentViewController: NSViewController(),
            contentSize: CGSize(width: 320, height: 240),
            presentsAsSheet: false
        ) {
            closeCount += 1
        }

        // Force nil-window guard paths.
        controller.window = nil
        controller.present(for: parent)
        controller.restoreDesiredContentSize()
        controller.dismiss()
        controller.reconcileWindowFrameForTesting()
        #expect(closeCount == 0)

        // Cover programmatic-close guard in windowWillClose.
        controller.setClosingProgrammaticallyForTesting(true)
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        #expect(closeCount == 0)

        controller.setClosingProgrammaticallyForTesting(false)
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        #expect(closeCount == 1)
    }

    @MainActor
    @Test("Status item controller updates menu state and executes quit callback")
    func freeStatusItemController() {
        var didQuit = false
        var didOpenApp = false
        let controller = FreeStatusItemController {
            didQuit = true
        }
        controller.setOpenAppHandler {
            didOpenApp = true
        }

        controller.update(
            statusText: "Focus Mode: Active",
            topBarText: "Focus: On",
            isQuitDisabled: true,
            iconColor: .systemGreen
        )
        controller.update(
            statusText: "Focus Mode: Inactive",
            topBarText: "Focus: Off",
            isQuitDisabled: false,
            iconColor: .labelColor
        )
        controller.update(
            statusText: "Focus Mode: Active\nCalendar: Active\nUnbreakable",
            topBarText: "",
            isQuitDisabled: true,
            iconColor: .systemGreen
        )
        controller.update(
            statusText: "\n\n",
            topBarText: "",
            isQuitDisabled: false,
            iconColor: .labelColor
        )
        if let statusMenu: NSMenu = mirrorValue(named: "statusMenu", in: controller) {
            #expect(statusMenu.items.count >= 3)
            #expect(statusMenu.items[1].isSeparatorItem)
        }

        let quitItem: NSMenuItem? = mirrorValue(named: "quitItem", in: controller)
        let openAppItem: NSMenuItem? = mirrorValue(named: "openAppItem", in: controller)
        #expect(openAppItem != nil)
        if let openAppItem, let action = openAppItem.action {
            _ = NSApp.sendAction(action, to: openAppItem.target, from: openAppItem)
        }
        #expect(didOpenApp)
        #expect(quitItem != nil)
        if let quitItem, let action = quitItem.action {
            _ = NSApp.sendAction(action, to: quitItem.target, from: quitItem)
        }
        #expect(didQuit)

        if let statusItem: NSStatusItem = mirrorValue(named: "statusItem", in: controller) {
            #expect(statusItem.button?.imagePosition == .imageOnly)
            NSStatusBar.system.removeStatusItem(statusItem)
            controller.update(
                statusText: "Focus Mode: Inactive",
                topBarText: "Focus: Off",
                isQuitDisabled: false,
                iconColor: .labelColor
            )
        }

        // Cover guard path when a status button cannot be resolved.
        controller.setStatusButtonProviderForTesting { nil }
        controller.update(
            statusText: "Focus Mode: Inactive",
            topBarText: "Focus: Off",
            isQuitDisabled: false,
            iconColor: .labelColor
        )
    }

    @MainActor
    @Test("Vertically centered text-field support covers drawing/edit/select paths")
    func verticallyCenteredTextFieldSupportCoverage() {
        let rect = NSRect(x: 0, y: 0, width: 220, height: 40)
        let cell = VerticallyCenteredTextFieldCell(textCell: "value")
        _ = cell.drawingRect(forBounds: rect)

        let hostField = NSTextField(frame: rect)
        let editor = NSTextView(frame: rect)
        cell.edit(withFrame: rect, in: hostField, editor: editor, delegate: nil, event: nil)
        cell.select(withFrame: rect, in: hostField, editor: editor, delegate: nil, start: 0, length: 3)

        let originalCellClass: AnyClass? = VerticallyCenteredTextField.cellClass
        VerticallyCenteredTextField.cellClass = NSTextFieldCell.self
        #expect(VerticallyCenteredTextField.cellClass == originalCellClass)
    }

    @Test("Rule-set alert presenters execute default class lookup")
    func alertPresenterDefaultClassLookupCoverage() {
        defer {
            AllowedWebsitesImportAlertPresenter.resetForTesting()
            AllowedWebsitesRuleSetAlertPresenter.resetForTesting()
            RulesSheetAlertPresenter.resetForTesting()
        }

        AllowedWebsitesImportAlertPresenter.resetForTesting()
        let importLookup = AllowedWebsitesImportAlertPresenter.classLookup
        #expect(importLookup("NSObject") != nil)

        AllowedWebsitesRuleSetAlertPresenter.resetForTesting()
        let allowedLookup = AllowedWebsitesRuleSetAlertPresenter.classLookup
        #expect(allowedLookup("NSObject") != nil)

        RulesSheetAlertPresenter.resetForTesting()
        let rulesLookup = RulesSheetAlertPresenter.classLookup
        #expect(rulesLookup("NSObject") != nil)
    }
}
