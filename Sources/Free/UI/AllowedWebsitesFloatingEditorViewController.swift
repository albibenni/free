import AppKit
import Combine

final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var adjustedRect = super.drawingRect(forBounds: rect)
        let textSize = cellSize(forBounds: rect)
        let delta = floor((adjustedRect.height - textSize.height) / 2)
        if delta > 0 {
            adjustedRect.origin.y += delta
            adjustedRect.size.height -= delta * 2
        }
        return adjustedRect
    }

    override func edit(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        event: NSEvent?
    ) {
        super.edit(
            withFrame: drawingRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            event: event
        )
    }

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) {
        super.select(
            withFrame: drawingRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: selStart,
            length: selLength
        )
    }
}

final class VerticallyCenteredTextField: NSTextField {
    override class var cellClass: AnyClass? {
        get { VerticallyCenteredTextFieldCell.self }
        set { }
    }
}

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

    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleRules.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("AllowedRuleCell")
        let cellView =
            (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView)
            ?? {
                let cell = NSTableCellView()
                cell.identifier = identifier
                let label = NSTextField(labelWithString: "")
                label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                label.textColor = .labelColor
                label.lineBreakMode = .byTruncatingMiddle
                label.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(label)
                cell.textField = label
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                    label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                    label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
                return cell
            }()
        if row >= 0, row < visibleRules.count {
            cellView.textField?.stringValue = visibleRules[row]
        }
        return cellView
    }
}
