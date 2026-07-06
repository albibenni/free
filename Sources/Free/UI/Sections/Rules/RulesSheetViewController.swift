import AppKit
import Combine

final class RulesSheetViewController: NSViewController {
    let appState: AppState
    var selectedSetId: UUID?
    var isSidebarVisible = true
    var isSuggestionsExpanded = false

    let sidebarContainer = AppKitDynamicView()
    let sidebarHeader = NSStackView()
    let sidebarScrollView = VerticalStackScrollContainer(contentInsets: NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
    let addRuleSetButton = NSButton()
    let mainContainer = AppKitDynamicView()
    let mainHeader = NSStackView()
    let mainTitleLabel = NSTextField(labelWithString: "")
    let toggleSidebarButton = NSButton()
    let contentScrollView = VerticalStackScrollContainer()
    let noSelectionLabel = NSTextField(labelWithString: "Select a list to edit")
    let rulesHeaderLabel = NSTextField(labelWithString: "Allowed in this list")
    let rulesEmptyLabel = NSTextField(labelWithString: "No rules yet.")
    let rulesRowsStack = NSStackView()
    let suggestionsDivider = makeAppKitDividerView(color: .separatorColor)
    let suggestionsButton = NSButton(
        title: "Open Tabs Suggestions",
        target: nil,
        action: nil
    )
    let suggestionsEmptyLabel = NSTextField(labelWithString: "")
    let suggestionsRowsStack = NSStackView()
    let addRuleField = NSTextField(string: "")
    let addRuleButton = ActionButton(title: "Add")
    let doneButton = ActionButton(title: "Done")
    let onDismiss: (() -> Void)?
    var reloadGeneration = 0
    var sidebarRowsById: [UUID: RulesSheetSidebarRowView] = [:]
    var ruleRowsByRule: [String: RulesSheetRuleRowView] = [:]
    var suggestionRowsByUrl: [String: RulesSheetSuggestionRowView] = [:]
    var cancellables: Set<AnyCancellable> = []

    init(appState: AppState, onDismiss: (() -> Void)? = nil) {
        self.appState = appState
        self.onDismiss = onDismiss
        selectedSetId = appState.currentPrimaryRuleSetId
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = CGSize(width: 900, height: 700)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RulesSheetViewController {
    var selectedSetIdForTesting: UUID? { selectedSetId }
    var isSidebarVisibleForTesting: Bool { isSidebarVisible }
    var isSuggestionsExpandedForTesting: Bool { isSuggestionsExpanded }
    var reloadGenerationForTesting: Int { reloadGeneration }

    func createSetForTesting(name: String) {
        let newSet = appState.createRuleSet(name: name, makeActive: false)
        selectedSetId = newSet.id
        reloadContent()
    }

    func selectRuleSetForTesting(_ ruleSet: RuleSet) {
        let nextSelectedSetId = RulesSheetActionsCoordinator.selectedSetIdAfterRowTap(
            tappedId: ruleSet.id,
            isBlocking: appState.isBlocking,
            currentSelectedId: selectedSetId
        )
        guard nextSelectedSetId != selectedSetId else { return }
        selectedSetId = nextSelectedSetId
        reloadSidebar()
        reloadRuleContent()
    }

    func deleteRuleSetForTesting(_ ruleSet: RuleSet) {
        appState.deleteSet(id: ruleSet.id)
        selectedSetId = RulesSheetActionsCoordinator.selectedSetIdAfterDelete(
            deletedId: ruleSet.id,
            currentSelectedId: selectedSetId,
            remainingRuleSets: appState.ruleSets
        )
        reloadContent()
    }

    func toggleSidebarForTesting() {
        toggleSidebar()
    }

    func toggleSuggestionsForTesting() {
        toggleSuggestions()
    }

    func setSuggestionsExpandedForTesting(_ expanded: Bool) {
        isSuggestionsExpanded = expanded
        reloadRuleContent()
    }

    func refreshSuggestionsForTestingAsync() async {
        await appState.refreshCurrentOpenUrlsAsync()
        reloadRuleContent()
    }

    func addSuggestionForTesting(url: String, setId: UUID) {
        appState.addSpecificRule(url, to: setId)
        reloadRuleContent()
    }

    func addRuleForTesting(_ rule: String, setId: UUID) {
        selectedSetId = setId
        addRuleField.stringValue = rule
        addRule()
    }

    func filteredSuggestionsForTesting(for selectedSet: RuleSet) -> [String] {
        RulesSectionSupport.filterSuggestions(appState.currentOpenUrls, existing: selectedSet)
    }

    func sidebarRowObjectIdentifierForTesting(_ id: UUID) -> ObjectIdentifier? {
        sidebarRowsById[id].map(ObjectIdentifier.init)
    }

    func ruleRowObjectIdentifierForTesting(_ rule: String) -> ObjectIdentifier? {
        ruleRowsByRule[rule].map(ObjectIdentifier.init)
    }

    func suggestionRowObjectIdentifierForTesting(_ url: String) -> ObjectIdentifier? {
        suggestionRowsByUrl[url].map(ObjectIdentifier.init)
    }
}
