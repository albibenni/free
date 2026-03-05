import AppKit
import Combine

final class AllowedWebsitesFloatingEditorViewController:
    NSViewController,
    NSTableViewDataSource,
    NSTableViewDelegate
{
    struct RenderSignature: Equatable {
        let ruleSets: [RuleSet]
        let activeRuleSetId: UUID?
        let isStrictActive: Bool
        let accentColorIndex: Int
    }

    let appState: AppState
    var selectedRuleSetId: UUID?
    var visibleRules: [String] = []
    var cancellables: Set<AnyCancellable> = []
    var importCandidateCheckboxes: [NSButton] = []
    var importCandidateRules: [String] = []
    var renderSignature: RenderSignature?

    let ruleSetScrollView = VerticalStackScrollContainer(
        contentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    )
    var ruleSetListHeightConstraint: NSLayoutConstraint?
    var ruleSetButtons: [UUID: AppKitSelectableRowButton] = [:]
    let createListButton = NSButton()
    let deleteListButton = NSButton()
    let urlField = VerticallyCenteredTextField(string: "")
    let addButton = ActionButton(title: "Add")
    let importOpenTabsButton = ActionButton(title: "Import Open Tabs")
    let removeButton = ActionButton(title: "Remove Selected")
    let emptyLabel = NSTextField(labelWithString: "No allowed websites in this list yet.")
    let rulesTableView = NSTableView()
    let tableScrollView = NSScrollView()

    init(appState: AppState, initialRuleSetId: UUID?) {
        self.appState = appState
        selectedRuleSetId = initialRuleSetId
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleObservedAppStateChange()
            }
            .store(in: &cancellables)
        reloadContent()
    }

    private func handleObservedAppStateChange() {
        let nextSignature = RenderSignature(
            ruleSets: appState.ruleSets,
            activeRuleSetId: appState.activeRuleSetId,
            isStrictActive: appState.isStrictActive,
            accentColorIndex: appState.accentColorIndex
        )
        guard renderSignature != nextSignature else { return }
        reloadContent()
    }

    func focusOnRuleSet(_ id: UUID?) {
        selectedRuleSetId = id
        reloadContent()
    }

}
