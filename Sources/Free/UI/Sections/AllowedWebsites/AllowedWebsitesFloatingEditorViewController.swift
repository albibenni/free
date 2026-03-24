import AppKit
import Combine

final class AllowedWebsitesFloatingEditorViewController:
    NSViewController
{
    struct RenderSignature: Equatable {
        let ruleSets: [RuleSet]
        let activeRuleSetId: UUID?
        let isUnblockable: Bool
        let accentColorIndex: Int
    }

    let appState: AppState
    var selectedRuleSetId: UUID?
    var visibleRules: [String] = []
    var cancellables: Set<AnyCancellable> = []

    let ruleSetScrollView = VerticalStackScrollContainer(
        contentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    )
    var ruleSetListHeightConstraint: NSLayoutConstraint?
    var warningTopConstraint: NSLayoutConstraint?
    var warningToDividerConstraint: NSLayoutConstraint?
    var warningCollapsedHeightConstraint: NSLayoutConstraint?
    var ruleSetButtons: [UUID: AppKitSelectableRowButton] = [:]
    let createListButton = NSButton()
    let deleteListButton = NSButton()
    let urlField = VerticallyCenteredTextField(string: "")
    let addButton = ActionButton(title: "Add")
    let importOpenTabsButton = ActionButton(title: "Import Open Tabs")
    let removeButton = ActionButton(title: "Remove Selected")
    let strictModeWarningLabel = NSTextField(
        labelWithString: "Strict mode is active. A challenge phrase is required to edit allowed websites."
    )
    let emptyLabel = NSTextField(labelWithString: "No allowed websites in this list yet.")
    let rulesTableView = NSTableView()
    let tableScrollView = NSScrollView()
    let rulesTableController = AllowedWebsitesRulesTableController()

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
        rulesTableController.numberOfRules = { [weak self] in
            self?.visibleRules.count ?? 0
        }
        rulesTableController.ruleAt = { [weak self] index in
            guard let self, index >= 0, index < visibleRules.count else { return nil }
            return visibleRules[index]
        }
        AppKitAppStateObservation.bind(
            publisher: AppKitAppStateObservation.allowedWebsitesPublisher(appState: appState),
            signature: { [appState] in
                AllowedWebsitesReloadCoordinator.renderSignature(appState: appState)
            },
            cancellables: &cancellables
        ) { [weak self] _ in
            self?.reloadContent()
        }
        reloadContent()
    }

    func focusOnRuleSet(_ id: UUID?) {
        selectedRuleSetId = id
        reloadContent()
    }

}
