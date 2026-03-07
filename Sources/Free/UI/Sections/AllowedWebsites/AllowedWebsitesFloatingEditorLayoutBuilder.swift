import AppKit

enum AllowedWebsitesFloatingEditorLayoutBuilder {
    struct Components {
        let ruleSetScrollView: VerticalStackScrollContainer
        let createListButton: NSButton
        let deleteListButton: NSButton
        let urlField: NSTextField
        let addButton: ActionButton
        let importOpenTabsButton: ActionButton
        let removeButton: ActionButton
        let rulesTableView: NSTableView
        let tableScrollView: NSScrollView
        let emptyLabel: NSTextField
    }

    struct BuildResult {
        let rootView: NSView
        let ruleSetListHeightConstraint: NSLayoutConstraint
    }

    static func build(
        target: AnyObject,
        components: Components,
        tableDelegate: NSTableViewDelegate,
        tableDataSource: NSTableViewDataSource
    ) -> BuildResult {
        let rootView = AppKitDynamicView()
        rootView.backgroundColorProvider = { NSColor.windowBackgroundColor }

        let listLabel = makeAppKitSectionLabel("LISTS")
        listLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        listLabel.textColor = .secondaryLabelColor

        components.ruleSetScrollView.drawsBackground = false
        components.ruleSetScrollView.borderType = .noBorder
        components.ruleSetScrollView.hasVerticalScroller = true
        components.ruleSetScrollView.autohidesScrollers = true
        components.ruleSetScrollView.translatesAutoresizingMaskIntoConstraints = false
        let ruleSetListHeightConstraint = components.ruleSetScrollView.heightAnchor.constraint(equalToConstant: 74)
        ruleSetListHeightConstraint.isActive = true

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
        listContainer.addSubview(components.ruleSetScrollView)

        NSLayoutConstraint.activate([
            components.ruleSetScrollView.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor, constant: 8),
            components.ruleSetScrollView.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor, constant: -8),
            components.ruleSetScrollView.topAnchor.constraint(equalTo: listContainer.topAnchor, constant: 8),
            components.ruleSetScrollView.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor, constant: -8),
        ])

        components.createListButton.target = target
        components.createListButton.action = #selector(AllowedWebsitesFloatingEditorViewController.handleCreateRuleSet)
        components.createListButton.translatesAutoresizingMaskIntoConstraints = false
        components.createListButton.widthAnchor.constraint(equalToConstant: 20).isActive = true
        components.createListButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
        components.createListButton.toolTip = "Create list"

        components.deleteListButton.target = target
        components.deleteListButton.action = #selector(AllowedWebsitesFloatingEditorViewController.handleDeleteRuleSet)
        components.deleteListButton.translatesAutoresizingMaskIntoConstraints = false
        components.deleteListButton.widthAnchor.constraint(equalToConstant: 20).isActive = true
        components.deleteListButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
        components.deleteListButton.toolTip = "Delete list"

        let headerRow = makeAppKitHorizontalRow(
            views: [listLabel, NSView(), components.createListButton, components.deleteListButton],
            alignment: .centerY,
            spacing: 10
        )
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        components.urlField.placeholderString = "Add URL to allow..."
        components.urlField.target = target
        components.urlField.action = #selector(AllowedWebsitesFloatingEditorViewController.handleAddRuleFromField(_:))
        components.urlField.translatesAutoresizingMaskIntoConstraints = false
        components.urlField.heightAnchor.constraint(equalToConstant: 30).isActive = true

        components.addButton.target = target
        components.addButton.action = #selector(AllowedWebsitesFloatingEditorViewController.handleAddRule)
        components.addButton.translatesAutoresizingMaskIntoConstraints = false
        components.addButton.widthAnchor.constraint(equalToConstant: 72).isActive = true
        components.addButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        components.addButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        components.addButton.setContentHuggingPriority(.required, for: .horizontal)

        components.importOpenTabsButton.target = target
        components.importOpenTabsButton.action = #selector(AllowedWebsitesFloatingEditorViewController.handleImportOpenTabs)
        components.importOpenTabsButton.translatesAutoresizingMaskIntoConstraints = false
        components.importOpenTabsButton.widthAnchor.constraint(equalToConstant: 148).isActive = true
        components.importOpenTabsButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        components.importOpenTabsButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        components.importOpenTabsButton.setContentHuggingPriority(.required, for: .horizontal)

        let addRow = makeAppKitHorizontalRow(
            views: [components.urlField, components.addButton, components.importOpenTabsButton],
            alignment: .centerY,
            spacing: 10
        )
        addRow.translatesAutoresizingMaskIntoConstraints = false

        let ruleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AllowedRule"))
        ruleColumn.title = "Allowed Websites"
        ruleColumn.resizingMask = .autoresizingMask
        components.rulesTableView.addTableColumn(ruleColumn)
        components.rulesTableView.headerView = nil
        components.rulesTableView.rowHeight = 28
        components.rulesTableView.intercellSpacing = NSSize(width: 0, height: 2)
        components.rulesTableView.usesAlternatingRowBackgroundColors = false
        components.rulesTableView.allowsMultipleSelection = true
        components.rulesTableView.delegate = tableDelegate
        components.rulesTableView.dataSource = tableDataSource
        components.rulesTableView.target = target
        components.rulesTableView.action = #selector(AllowedWebsitesFloatingEditorViewController.handleTableSelectionChange)
        components.rulesTableView.doubleAction = #selector(AllowedWebsitesFloatingEditorViewController.handleRemoveSelected)

        components.tableScrollView.documentView = components.rulesTableView
        components.tableScrollView.hasVerticalScroller = true
        components.tableScrollView.autohidesScrollers = true
        components.tableScrollView.drawsBackground = false
        components.tableScrollView.borderType = .noBorder
        components.tableScrollView.translatesAutoresizingMaskIntoConstraints = false

        components.emptyLabel.textColor = .secondaryLabelColor
        components.emptyLabel.alignment = .center
        components.emptyLabel.translatesAutoresizingMaskIntoConstraints = false

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
        tableContainer.addSubview(components.tableScrollView)
        tableContainer.addSubview(components.emptyLabel)

        NSLayoutConstraint.activate([
            components.tableScrollView.leadingAnchor.constraint(equalTo: tableContainer.leadingAnchor, constant: 8),
            components.tableScrollView.trailingAnchor.constraint(equalTo: tableContainer.trailingAnchor, constant: -8),
            components.tableScrollView.topAnchor.constraint(equalTo: tableContainer.topAnchor, constant: 8),
            components.tableScrollView.bottomAnchor.constraint(equalTo: tableContainer.bottomAnchor, constant: -8),

            components.emptyLabel.centerXAnchor.constraint(equalTo: tableContainer.centerXAnchor),
            components.emptyLabel.centerYAnchor.constraint(equalTo: tableContainer.centerYAnchor),
        ])

        components.removeButton.target = target
        components.removeButton.action = #selector(AllowedWebsitesFloatingEditorViewController.handleRemoveSelected)
        components.removeButton.translatesAutoresizingMaskIntoConstraints = false
        components.removeButton.widthAnchor.constraint(equalToConstant: 152).isActive = true
        components.removeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        components.removeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        components.removeButton.setContentHuggingPriority(.required, for: .horizontal)

        let footerRow = makeAppKitHorizontalRow(
            views: [NSView(), components.removeButton],
            alignment: .centerY,
            spacing: 10
        )
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        let divider = makeAppKitDividerView()
        divider.translatesAutoresizingMaskIntoConstraints = false

        [headerRow, listContainer, addRow, divider, tableContainer, footerRow].forEach {
            rootView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 14),
            headerRow.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -14),
            headerRow.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 14),

            listContainer.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 14),
            listContainer.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -14),
            listContainer.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 8),

            addRow.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 14),
            addRow.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -14),
            addRow.topAnchor.constraint(equalTo: listContainer.bottomAnchor, constant: 12),

            divider.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            divider.topAnchor.constraint(equalTo: addRow.bottomAnchor, constant: 12),

            tableContainer.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 14),
            tableContainer.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -14),
            tableContainer.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            tableContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),

            footerRow.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 14),
            footerRow.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -14),
            footerRow.topAnchor.constraint(equalTo: tableContainer.bottomAnchor, constant: 10),
            footerRow.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -14),
        ])

        return BuildResult(
            rootView: rootView,
            ruleSetListHeightConstraint: ruleSetListHeightConstraint
        )
    }
}
