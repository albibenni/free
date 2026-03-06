import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    @objc
    func handleCreateRuleSet() {
        guard AllowedWebsitesRuleSetActionsCoordinator.canCreateRuleSet(
            isStrictActive: appState.isStrictActive
        ) else { return }

        guard let name = AllowedWebsitesRuleSetAlertPresenter.promptForNewRuleSetName() else { return }

        let newSet = AllowedWebsitesRuleSetActionsCoordinator.createRuleSet(
            appState: appState,
            name: name
        )
        selectedRuleSetId = newSet.id
        reloadContent()
    }

    @objc
    func handleDeleteRuleSet() {
        guard AllowedWebsitesRuleSetActionsCoordinator.canDeleteRuleSet(
            isStrictActive: appState.isStrictActive,
            ruleSetCount: appState.ruleSets.count
        ) else { return }
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        guard let selectedSet = AllowedWebsitesRuleSetActionsCoordinator.selectedRuleSet(
            id: setId,
            ruleSets: appState.ruleSets
        ) else { return }

        guard AllowedWebsitesRuleSetAlertPresenter.confirmDeleteRuleSet(named: selectedSet.name) else { return }

        AllowedWebsitesRuleSetActionsCoordinator.deleteRuleSet(
            appState: appState,
            id: setId
        )
        selectedRuleSetId = resolvedRuleSetId(nil)
        reloadContent()
    }

    @objc
    func handleAddRule() {
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        let didAdd = AllowedWebsitesRuleActionsCoordinator.addRule(
            appState: appState,
            setId: setId,
            rawValue: urlField.stringValue
        )
        guard didAdd else { return }
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
        let rulesToRemove = AllowedWebsitesSelectionCoordinator.selectedRules(
            indexes: rulesTableView.selectedRowIndexes,
            visibleRules: visibleRules
        )
        let removedCount = AllowedWebsitesRuleActionsCoordinator.removeRules(
            appState: appState,
            setId: setId,
            rules: rulesToRemove
        )
        guard removedCount > 0 else { return }
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

        ruleSetListHeightConstraint?.constant = AllowedWebsitesPresentationCoordinator.ruleSetListHeight(
            ruleSetCount: appState.ruleSets.count
        )
    }

    func reloadRulesOnly() {
        let previouslySelectedRules = Set(AllowedWebsitesSelectionCoordinator.selectedRules(
            indexes: rulesTableView.selectedRowIndexes,
            visibleRules: visibleRules
        ))

        visibleRules = AllowedWebsitesPresentationCoordinator.visibleRules(
            selectedRuleSetId: selectedRuleSetId,
            ruleSets: appState.ruleSets
        )
        rulesTableView.reloadData()

        if !previouslySelectedRules.isEmpty {
            let selectedIndexes = AllowedWebsitesSelectionCoordinator.selectedIndexes(
                preserving: previouslySelectedRules,
                in: visibleRules
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
        let state = AllowedWebsitesPresentationCoordinator.controlState(
            selectedRuleSetId: resolvedRuleSetId(selectedRuleSetId),
            isStrictActive: appState.isStrictActive,
            selectedIndexes: rulesTableView.selectedRowIndexes,
            visibleRulesCount: visibleRules.count,
            ruleSetCount: appState.ruleSets.count
        )
        urlField.isEnabled = state.canEdit
        addButton.isEnabled = state.canEdit
        importOpenTabsButton.isEnabled = state.canEdit
        removeButton.isEnabled = state.canRemove
        createListButton.isEnabled = state.canCreateList
        deleteListButton.isEnabled = state.canDeleteList
        for button in ruleSetButtons.values {
            button.isEnabled = state.canCreateList
        }
    }

    func resolvedRuleSetId(_ id: UUID?) -> UUID? {
        AllowedWebsitesSelectionCoordinator.resolvedRuleSetId(
            id,
            ruleSets: appState.ruleSets,
            activeRuleSetId: appState.activeRuleSetId
        )
    }
}
