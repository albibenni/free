import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    @objc
    func handleCreateRuleSet() {
        guard !appState.isStrictActive else { return }

        let alert = NSAlert()
        alert.messageText = "New Allowed List"
        let input = NSTextField(string: "")
        input.placeholderString = "List Name"
        input.frame = CGRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let newSet = appState.createRuleSet(name: input.stringValue, makeActive: false)
        selectedRuleSetId = newSet.id
        reloadContent()
    }

    @objc
    func handleDeleteRuleSet() {
        guard !appState.isStrictActive else { return }
        guard appState.ruleSets.count > 1 else { return }
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        guard let selectedSet = appState.ruleSets.first(where: { $0.id == setId }) else { return }

        let alert = NSAlert()
        alert.messageText = "Delete \"\(selectedSet.name)\"?"
        alert.informativeText = "This removes the list and all its allowed websites."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        appState.deleteSet(id: setId)
        selectedRuleSetId = resolvedRuleSetId(nil)
        reloadContent()
    }

    @objc
    func handleAddRule() {
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        let normalized = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        appState.addRule(normalized, to: setId)
        urlField.stringValue = ""
        reloadRulesOnly()
    }

    @objc
    func handleAddRuleFromField(_ sender: NSTextField) {
        handleAddRule()
    }

    @objc
    func handleRemoveSelected() {
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        let selectedIndexes = rulesTableView.selectedRowIndexes.filter { $0 >= 0 && $0 < visibleRules.count }
        guard !selectedIndexes.isEmpty else { return }
        let rulesToRemove = selectedIndexes.map { visibleRules[$0] }
        for rule in rulesToRemove {
            appState.removeRule(rule, from: setId)
        }
        reloadRulesOnly()
    }

    @objc
    func handleTableSelectionChange() {
        updateControlStates()
    }

    func reloadContent() {
        renderSignature = RenderSignature(
            ruleSets: appState.ruleSets,
            activeRuleSetId: appState.activeRuleSetId,
            isStrictActive: appState.isStrictActive,
            accentColorIndex: appState.accentColorIndex
        )
        let previousSelection = selectedRuleSetId
        let resolvedSelection = resolvedRuleSetId(previousSelection)
        selectedRuleSetId = resolvedSelection
        reloadRuleSetRows()
        reloadRulesOnly()
    }

    func reloadRuleSetRows() {
        let stack = ruleSetScrollView.stackView
        for subview in stack.arrangedSubviews {
            stack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        ruleSetButtons.removeAll()

        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        for set in appState.ruleSets {
            let button = makeAppKitSelectableRowButton(
                title: set.name,
                isSelected: selectedRuleSetId == set.id,
                accentColor: accentColor
            ) { [weak self] in
                guard let self else { return }
                guard !self.appState.isStrictActive else { return }
                self.selectedRuleSetId = set.id
                self.reloadRuleSetRows()
                self.reloadRulesOnly()
            }
            button.isEnabled = !appState.isStrictActive
            stack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            ruleSetButtons[set.id] = button
        }

        let rowCount = max(appState.ruleSets.count, 1)
        let desiredHeight = CGFloat(rowCount) * 38
        ruleSetListHeightConstraint?.constant = min(max(desiredHeight, 38), 150)
    }

    func reloadRulesOnly() {
        let previouslySelectedRules = Set(
            rulesTableView.selectedRowIndexes
                .filter { $0 >= 0 && $0 < visibleRules.count }
                .map { visibleRules[$0] }
        )

        visibleRules =
            appState.ruleSets.first(where: { $0.id == selectedRuleSetId })?.urls
            ?? []
        rulesTableView.reloadData()

        if !previouslySelectedRules.isEmpty {
            let selectedIndexes = IndexSet(
                visibleRules.enumerated().compactMap { index, rule in
                    previouslySelectedRules.contains(rule) ? index : nil
                }
            )
            if !selectedIndexes.isEmpty {
                rulesTableView.selectRowIndexes(selectedIndexes, byExtendingSelection: false)
            }
        }

        emptyLabel.isHidden = !visibleRules.isEmpty
        updateControlStates()
        applyButtonStyling()
    }

    func updateControlStates() {
        let canEdit = resolvedRuleSetId(selectedRuleSetId) != nil && !appState.isStrictActive
        let hasSelection = rulesTableView.selectedRowIndexes.contains { $0 >= 0 && $0 < visibleRules.count }
        let canRemove = canEdit && hasSelection
        urlField.isEnabled = canEdit
        addButton.isEnabled = canEdit
        importOpenTabsButton.isEnabled = canEdit
        removeButton.isEnabled = canRemove
        createListButton.isEnabled = !appState.isStrictActive
        deleteListButton.isEnabled = !appState.isStrictActive && appState.ruleSets.count > 1
        for button in ruleSetButtons.values {
            button.isEnabled = !appState.isStrictActive
        }
    }

    func resolvedRuleSetId(_ id: UUID?) -> UUID? {
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
