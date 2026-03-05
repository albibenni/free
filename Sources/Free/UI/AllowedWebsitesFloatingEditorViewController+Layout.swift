import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    override func loadView() {
        let rootView = AppKitDynamicView()
        rootView.backgroundColorProvider = { NSColor.windowBackgroundColor }
        view = rootView

        let listLabel = makeAppKitSectionLabel("LISTS")
        listLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        listLabel.textColor = .secondaryLabelColor

        ruleSetScrollView.drawsBackground = false
        ruleSetScrollView.borderType = .noBorder
        ruleSetScrollView.hasVerticalScroller = true
        ruleSetScrollView.autohidesScrollers = true
        ruleSetScrollView.translatesAutoresizingMaskIntoConstraints = false
        ruleSetListHeightConstraint = ruleSetScrollView.heightAnchor.constraint(equalToConstant: 74)
        ruleSetListHeightConstraint?.isActive = true

        let listContainer = AppKitDynamicView()
        listContainer.backgroundColorProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.35)
        }
        listContainer.borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.45)
        }
        listContainer.borderWidthValue = 1
        listContainer.wantsLayer = true
        listContainer.layer?.cornerRadius = 8
        listContainer.translatesAutoresizingMaskIntoConstraints = false
        listContainer.addSubview(ruleSetScrollView)

        NSLayoutConstraint.activate([
            ruleSetScrollView.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor, constant: 8),
            ruleSetScrollView.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor, constant: -8),
            ruleSetScrollView.topAnchor.constraint(equalTo: listContainer.topAnchor, constant: 8),
            ruleSetScrollView.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor, constant: -8),
        ])

        createListButton.target = self
        createListButton.action = #selector(handleCreateRuleSet)
        createListButton.translatesAutoresizingMaskIntoConstraints = false
        createListButton.widthAnchor.constraint(equalToConstant: 20).isActive = true
        createListButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
        createListButton.toolTip = "Create list"

        deleteListButton.target = self
        deleteListButton.action = #selector(handleDeleteRuleSet)
        deleteListButton.translatesAutoresizingMaskIntoConstraints = false
        deleteListButton.widthAnchor.constraint(equalToConstant: 20).isActive = true
        deleteListButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
        deleteListButton.toolTip = "Delete list"

        let headerRow = NSStackView(views: [listLabel, NSView(), createListButton, deleteListButton])
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

        importOpenTabsButton.target = self
        importOpenTabsButton.action = #selector(handleImportOpenTabs)
        importOpenTabsButton.translatesAutoresizingMaskIntoConstraints = false
        importOpenTabsButton.widthAnchor.constraint(equalToConstant: 148).isActive = true
        importOpenTabsButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        importOpenTabsButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        importOpenTabsButton.setContentHuggingPriority(.required, for: .horizontal)

        let addRow = NSStackView(views: [urlField, addButton, importOpenTabsButton])
        addRow.orientation = .horizontal
        addRow.alignment = .centerY
        addRow.spacing = 10
        addRow.translatesAutoresizingMaskIntoConstraints = false

        let ruleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AllowedRule"))
        ruleColumn.title = "Allowed Websites"
        ruleColumn.resizingMask = .autoresizingMask
        rulesTableView.addTableColumn(ruleColumn)
        rulesTableView.headerView = nil
        rulesTableView.rowHeight = 28
        rulesTableView.intercellSpacing = NSSize(width: 0, height: 2)
        rulesTableView.usesAlternatingRowBackgroundColors = false
        rulesTableView.allowsMultipleSelection = true
        rulesTableView.delegate = self
        rulesTableView.dataSource = self
        rulesTableView.target = self
        rulesTableView.action = #selector(handleTableSelectionChange)
        rulesTableView.doubleAction = #selector(handleRemoveSelected)

        tableScrollView.documentView = rulesTableView
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

        [headerRow, listContainer, addRow, divider, tableContainer, footerRow].forEach {
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            headerRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            headerRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),

            listContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            listContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            listContainer.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 8),

            addRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            addRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            addRow.topAnchor.constraint(equalTo: listContainer.bottomAnchor, constant: 12),

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

    func applyButtonStyling() {
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        styleActionButton(addButton, title: "Add", color: accentColor)
        styleActionButton(importOpenTabsButton, title: "Import Open Tabs", color: accentColor)
        styleActionButton(removeButton, title: "Remove Selected", color: accentColor)
        styleHeaderIconButtons(color: accentColor)
    }

    private func styleHeaderIconButtons(color _: NSColor) {
        configureAppKitIconButton(
            createListButton,
            symbol: AppKitUISymbols.addList,
            color: NSColor.secondaryLabelColor,
            backgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.5),
            cornerRadius: 5
        )
        configureAppKitIconButton(
            deleteListButton,
            symbol: AppKitUISymbols.deleteList,
            color: NSColor.secondaryLabelColor,
            backgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.5),
            cornerRadius: 5
        )
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
}
