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
        let state = AllowedWebsitesReloadCoordinator.reloadState(
            appState: appState,
            previousSelectedRuleSetId: selectedRuleSetId
        )
        renderSignature = state.renderSignature
        selectedRuleSetId = state.selectedRuleSetId
        reloadRuleSetRows()
        reloadRulesOnly()
    }

    func reloadRuleSetRows() {
        let rows = AllowedWebsitesPresentationCoordinator.ruleSetRows(
            selectedRuleSetId: selectedRuleSetId,
            ruleSets: appState.ruleSets
        )
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        ruleSetButtons = AllowedWebsitesRuleSetListBuilder.rebuild(
            in: ruleSetScrollView.stackView,
            rows: rows,
            accentColor: accentColor,
            isRowSelectionEnabled: !appState.isStrictActive
        ) { [weak self] selectedId in
            guard let self else { return }
            self.selectedRuleSetId = AllowedWebsitesRuleSetActionsCoordinator.selectedRuleSetAfterRowTap(
                tappedId: selectedId,
                currentSelectedId: self.selectedRuleSetId,
                isStrictActive: self.appState.isStrictActive
            )
            self.reloadRuleSetRows()
            self.reloadRulesOnly()
        }

        ruleSetListHeightConstraint?.constant = AllowedWebsitesPresentationCoordinator.ruleSetListHeight(
            ruleSetCount: appState.ruleSets.count
        )
    }

    func reloadRulesOnly() {
        let contentState = AllowedWebsitesPresentationCoordinator.rulesContentState(
            selectedRuleSetId: selectedRuleSetId,
            ruleSets: appState.ruleSets,
            previousVisibleRules: visibleRules,
            previousSelection: rulesTableView.selectedRowIndexes
        )
        visibleRules = contentState.visibleRules
        rulesTableView.reloadData()
        if !contentState.preservedSelection.isEmpty {
            rulesTableView.selectRowIndexes(contentState.preservedSelection, byExtendingSelection: false)
        }

        emptyLabel.isHidden = !contentState.showsEmptyState
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
        AllowedWebsitesControlStateApplier.apply(
            state,
            urlField: urlField,
            addButton: addButton,
            importOpenTabsButton: importOpenTabsButton,
            removeButton: removeButton,
            createListButton: createListButton,
            deleteListButton: deleteListButton,
            ruleSetButtons: ruleSetButtons
        )
    }

    func resolvedRuleSetId(_ id: UUID?) -> UUID? {
        AllowedWebsitesSelectionCoordinator.resolvedRuleSetId(
            id,
            ruleSets: appState.ruleSets,
            activeRuleSetId: appState.activeRuleSetId
        )
    }
}
