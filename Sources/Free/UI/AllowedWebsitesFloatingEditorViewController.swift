import AppKit
import Combine

final class AllowedWebsitesFloatingEditorViewController:
    NSViewController,
    NSTableViewDataSource,
    NSTableViewDelegate
{
    private let appState: AppState
    private var selectedRuleSetId: UUID?
    private var visibleRules: [String] = []
    private var cancellables: Set<AnyCancellable> = []

    private let listPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let urlField = NSTextField(string: "")
    private let addButton = ActionButton(title: "Add")
    private let removeButton = ActionButton(title: "Remove Selected")
    private let emptyLabel = NSTextField(labelWithString: "No allowed websites in this list yet.")
    private let tableView = NSTableView()
    private let tableScrollView = NSScrollView()

    init(appState: AppState, initialRuleSetId: UUID?) {
        self.appState = appState
        selectedRuleSetId = initialRuleSetId
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = AppKitDynamicView()
        rootView.backgroundColorProvider = { NSColor.windowBackgroundColor }
        view = rootView

        let listLabel = NSTextField(labelWithString: "List")
        listLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        listLabel.textColor = .secondaryLabelColor

        listPopup.target = self
        listPopup.action = #selector(handleRuleSetSelection)
        listPopup.translatesAutoresizingMaskIntoConstraints = false
        listPopup.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let headerRow = NSStackView(views: [listLabel, listPopup, NSView()])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 10
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        urlField.placeholderString = "Add URL to allow..."
        urlField.target = self
        urlField.action = #selector(handleAddRuleFromField(_:))
        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.heightAnchor.constraint(equalToConstant: 30).isActive = true

        addButton.target = self
        addButton.action = #selector(handleAddRule)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.widthAnchor.constraint(equalToConstant: 72).isActive = true
        addButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        addButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        addButton.setContentHuggingPriority(.required, for: .horizontal)

        let addRow = NSStackView(views: [urlField, addButton])
        addRow.orientation = .horizontal
        addRow.alignment = .centerY
        addRow.spacing = 10
        addRow.translatesAutoresizingMaskIntoConstraints = false

        let ruleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AllowedRule"))
        ruleColumn.title = "Allowed Websites"
        ruleColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(ruleColumn)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.action = #selector(handleTableSelectionChange)
        tableView.doubleAction = #selector(handleRemoveSelected)

        tableScrollView.documentView = tableView
        tableScrollView.hasVerticalScroller = true
        tableScrollView.autohidesScrollers = true
        tableScrollView.drawsBackground = false
        tableScrollView.borderType = .noBorder
        tableScrollView.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        let tableContainer = AppKitDynamicView()
        tableContainer.backgroundColorProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.35)
        }
        tableContainer.borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.45)
        }
        tableContainer.borderWidthValue = 1
        tableContainer.wantsLayer = true
        tableContainer.layer?.cornerRadius = 8
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.addSubview(tableScrollView)
        tableContainer.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableScrollView.leadingAnchor.constraint(equalTo: tableContainer.leadingAnchor, constant: 8),
            tableScrollView.trailingAnchor.constraint(equalTo: tableContainer.trailingAnchor, constant: -8),
            tableScrollView.topAnchor.constraint(equalTo: tableContainer.topAnchor, constant: 8),
            tableScrollView.bottomAnchor.constraint(equalTo: tableContainer.bottomAnchor, constant: -8),

            emptyLabel.centerXAnchor.constraint(equalTo: tableContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableContainer.centerYAnchor),
        ])

        removeButton.target = self
        removeButton.action = #selector(handleRemoveSelected)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.widthAnchor.constraint(equalToConstant: 152).isActive = true
        removeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        removeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        removeButton.setContentHuggingPriority(.required, for: .horizontal)

        let footerRow = NSStackView(views: [NSView(), removeButton])
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY
        footerRow.spacing = 10
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        let divider = makeAppKitDividerView()
        divider.translatesAutoresizingMaskIntoConstraints = false

        [headerRow, addRow, divider, tableContainer, footerRow].forEach {
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            headerRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            headerRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),

            addRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            addRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            addRow.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 12),

            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.topAnchor.constraint(equalTo: addRow.bottomAnchor, constant: 12),

            tableContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            tableContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            tableContainer.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            tableContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),

            footerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            footerRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            footerRow.topAnchor.constraint(equalTo: tableContainer.bottomAnchor, constant: 10),
            footerRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadContent()
            }
            .store(in: &cancellables)
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

    @objc
    private func handleRuleSetSelection() {
        guard let selectedItem = listPopup.selectedItem else { return }
        guard let rawId = selectedItem.representedObject as? String else { return }
        selectedRuleSetId = UUID(uuidString: rawId)
        reloadRulesOnly()
    }

    @objc
    private func handleAddRule() {
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        let normalized = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        appState.addRule(normalized, to: setId)
        urlField.stringValue = ""
        reloadRulesOnly()
    }

    @objc
    private func handleAddRuleFromField(_ sender: NSTextField) {
        handleAddRule()
    }

    @objc
    private func handleRemoveSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < visibleRules.count else { return }
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        appState.removeRule(visibleRules[row], from: setId)
        reloadRulesOnly()
    }

    @objc
    private func handleTableSelectionChange() {
        updateControlStates()
    }

    private func reloadContent() {
        let previousSelection = selectedRuleSetId
        let resolvedSelection = resolvedRuleSetId(previousSelection)
        selectedRuleSetId = resolvedSelection
        reloadRuleSetPopup()
        reloadRulesOnly()
    }

    private func reloadRuleSetPopup() {
        let selectedRawValue = selectedRuleSetId?.uuidString
        listPopup.removeAllItems()
        for ruleSet in appState.ruleSets {
            listPopup.addItem(withTitle: ruleSet.name)
            listPopup.lastItem?.representedObject = ruleSet.id.uuidString
        }
        if let selectedRawValue {
            for (index, item) in listPopup.itemArray.enumerated() {
                if (item.representedObject as? String) == selectedRawValue {
                    listPopup.selectItem(at: index)
                    break
                }
            }
        } else if listPopup.numberOfItems > 0 {
            listPopup.selectItem(at: 0)
            if let rawId = listPopup.selectedItem?.representedObject as? String {
                selectedRuleSetId = UUID(uuidString: rawId)
            }
        }
    }

    private func reloadRulesOnly() {
        visibleRules =
            appState.ruleSets.first(where: { $0.id == selectedRuleSetId })?.urls
            ?? []
        tableView.reloadData()
        emptyLabel.isHidden = !visibleRules.isEmpty
        updateControlStates()
        applyButtonStyling()
    }

    private func applyButtonStyling() {
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        styleActionButton(addButton, title: "Add", color: accentColor)
        styleActionButton(removeButton, title: "Remove Selected", color: accentColor)
    }

    private func styleActionButton(_ button: ActionButton, title: String, color: NSColor) {
        button.isBordered = false
        button.layer?.cornerRadius = AppKitUIConstants.CornerRadius.control
        button.focusRingType = .none
        button.setGradientBackground(
            colors: [
                color.withAlphaComponent(0.14),
                color.withAlphaComponent(0.08),
            ],
            borderColor: color.withAlphaComponent(0.28)
        )
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: AppKitUIConstants.Typography.buttonLabel,
                .foregroundColor: color,
            ]
        )
        button.contentTintColor = color
    }

    private func updateControlStates() {
        let canEdit = resolvedRuleSetId(selectedRuleSetId) != nil && !appState.isStrictActive
        let canRemove = canEdit && tableView.selectedRow >= 0 && tableView.selectedRow < visibleRules.count
        urlField.isEnabled = canEdit
        addButton.isEnabled = canEdit
        removeButton.isEnabled = canRemove
        listPopup.isEnabled = !appState.ruleSets.isEmpty
    }

    private func resolvedRuleSetId(_ id: UUID?) -> UUID? {
        if let id, appState.ruleSets.contains(where: { $0.id == id }) {
            return id
        }
        if let activeId = appState.activeRuleSetId,
           appState.ruleSets.contains(where: { $0.id == activeId })
        {
            return activeId
        }
        return appState.ruleSets.first?.id
    }
}
