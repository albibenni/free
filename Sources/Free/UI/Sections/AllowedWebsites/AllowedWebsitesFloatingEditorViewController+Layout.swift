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
                rulesTableView: rulesTableView,
                tableScrollView: tableScrollView,
                emptyLabel: emptyLabel
            ),
            tableDelegate: rulesTableController,
            tableDataSource: rulesTableController
        )
        view = result.rootView
        ruleSetListHeightConstraint = result.ruleSetListHeightConstraint
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
