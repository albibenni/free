import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    var isAllowedWebsitesEditingLocked: Bool {
        appState.isUnblockable && appState.isBlocking
    }

    @objc
    func handleCreateRuleSet() {
        guard AllowedWebsitesRuleSetActionsCoordinator.canCreateRuleSet(
            isStrictActive: isAllowedWebsitesEditingLocked
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
        guard !isAllowedWebsitesEditingLocked else { return }
        guard appState.ruleSets.count > 1 else { return }
        let setId: UUID
        if let selectedRuleSetId {
            setId = selectedRuleSetId
        } else if let activeRuleSetId = appState.activeRuleSetId {
            setId = activeRuleSetId
        } else {
            setId = appState.ruleSets[0].id
        }
        let selectedSetName = AllowedWebsitesRuleSetActionsCoordinator.selectedRuleSet(
            id: setId,
            ruleSets: appState.ruleSets
        )?.name ?? "Selected List"

        guard AllowedWebsitesRuleSetAlertPresenter.confirmDeleteRuleSet(named: selectedSetName) else { return }

        AllowedWebsitesRuleSetActionsCoordinator.deleteRuleSet(
            appState: appState,
            id: setId
        )
        selectedRuleSetId = resolvedRuleSetId(nil)
        reloadContent()
    }

    @objc
    func handleAddRule() {
        guard !isAllowedWebsitesEditingLocked else { return }
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        guard let normalized = AllowedWebsitesRuleActionsCoordinator.normalizedRuleInput(urlField.stringValue)
        else { return }
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
        guard !isAllowedWebsitesEditingLocked else { return }
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        let rulesToRemove = AllowedWebsitesSelectionCoordinator.selectedRules(
            indexes: rulesTableView.selectedRowIndexes,
            visibleRules: visibleRules
        )
        guard !rulesToRemove.isEmpty else { return }
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
        withAppKitSignpost("AllowedWebsitesReloadContent") {
            let state = AllowedWebsitesReloadCoordinator.reloadState(
                appState: appState,
                previousSelectedRuleSetId: selectedRuleSetId
            )
            selectedRuleSetId = state.selectedRuleSetId
            reloadRuleSetRows()
            reloadRulesOnly()
        }
    }

    func reloadRuleSetRows() {
        let rows = AllowedWebsitesPresentationCoordinator.ruleSetRows(
            selectedRuleSetId: selectedRuleSetId,
            ruleSets: appState.ruleSets
        )
        let accentColor = FocusColor.nsColor(for: appState.accentColorIndex)
        ruleSetButtons = AllowedWebsitesRuleSetListBuilder.updateOrRebuild(
            in: ruleSetScrollView.stackView,
            rows: rows,
            accentColor: accentColor,
            isRowSelectionEnabled: !isAllowedWebsitesEditingLocked,
            existingButtons: ruleSetButtons
        ) { [weak self] selectedId in
            guard let self else { return }
            self.selectedRuleSetId = AllowedWebsitesRuleSetActionsCoordinator.selectedRuleSetAfterRowTap(
                tappedId: selectedId,
                currentSelectedId: self.selectedRuleSetId,
                isStrictActive: self.isAllowedWebsitesEditingLocked
            )
            self.reloadRuleSetRows()
            self.reloadRulesOnly()
        }

        ruleSetListHeightConstraint?.constant = AllowedWebsitesPresentationCoordinator.ruleSetListHeight(
            ruleSetCount: appState.ruleSets.count
        )
    }

    func reloadRulesOnly() {
        withAppKitSignpost("AllowedWebsitesReloadRulesOnly") {
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
    }

    func updateControlStates() {
        let state = AllowedWebsitesPresentationCoordinator.controlState(
            selectedRuleSetId: resolvedRuleSetId(selectedRuleSetId),
            isStrictActive: isAllowedWebsitesEditingLocked,
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
