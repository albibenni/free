import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    override func loadView() {
        let result = AllowedWebsitesFloatingEditorLayoutBuilder.build(
            target: self,
            components: .init(
                ruleSetScrollView: ruleSetScrollView,
                createListButton: createListButton,
                deleteListButton: deleteListButton,
                urlField: urlField,
                addButton: addButton,
                importOpenTabsButton: importOpenTabsButton,
                removeButton: removeButton,
                strictModeWarningLabel: strictModeWarningLabel,
                rulesTableView: rulesTableView,
                tableScrollView: tableScrollView,
                emptyLabel: emptyLabel
            ),
            tableDelegate: rulesTableController,
            tableDataSource: rulesTableController
        )
        view = result.rootView
        ruleSetListHeightConstraint = result.ruleSetListHeightConstraint
        warningTopConstraint = result.warningTopConstraint
        warningToDividerConstraint = result.warningToDividerConstraint
        warningCollapsedHeightConstraint = result.warningCollapsedHeightConstraint
    }

    func applyButtonStyling() {
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        applyAppKitListActionButtonStyle(addButton, title: "Add", color: accentColor)
        applyAppKitListActionButtonStyle(
            importOpenTabsButton,
            title: "Import Open Tabs",
            color: accentColor
        )
        applyAppKitListActionButtonStyle(removeButton, title: "Remove Selected", color: accentColor)
        styleHeaderIconButtons(color: accentColor)
        strictModeWarningLabel.textColor = .systemOrange
        strictModeWarningLabel.font = .systemFont(ofSize: 12, weight: .regular)
        if isAllowedWebsitesEditingLocked {
            strictModeWarningLabel.isHidden = false
            warningCollapsedHeightConstraint?.isActive = false
            warningTopConstraint?.constant = 8
        } else {
            strictModeWarningLabel.isHidden = true
            warningCollapsedHeightConstraint?.isActive = true
            warningTopConstraint?.constant = 0
        }
        warningToDividerConstraint?.constant = 8
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

}
