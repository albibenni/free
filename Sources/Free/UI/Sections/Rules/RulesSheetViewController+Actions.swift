import AppKit

extension RulesSheetViewController {
    @objc
    func toggleSidebar() {
        isSidebarVisible.toggle()
        updateSidebarVisibility()
        reloadRuleContent()
    }

    @objc
    func addRuleSet() {
        guard let name = RulesSheetAlertPresenter.promptForNewRuleSetName() else { return }
        let newSet = appState.createRuleSet(name: name, makeActive: false)
        selectedSetId = newSet.id
        reloadContent()
    }

    @objc
    func selectRuleSet(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        let nextSelectedSetId = RulesSheetActionsCoordinator.selectedSetIdAfterRowTap(
            tappedId: id,
            isBlocking: appState.isBlocking,
            currentSelectedId: selectedSetId
        )
        guard nextSelectedSetId != selectedSetId else { return }
        selectedSetId = nextSelectedSetId
        reloadSidebar()
        reloadRuleContent()
    }

    @objc
    func deleteRuleSet(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        appState.deleteSet(id: id)
        selectedSetId = RulesSheetActionsCoordinator.selectedSetIdAfterDelete(
            deletedId: id,
            currentSelectedId: selectedSetId,
            remainingRuleSets: appState.ruleSets
        )
        reloadContent()
    }

    @objc
    func deleteRule(_ sender: NSButton) {
        guard let rule = sender.identifier?.rawValue, let setId = selectedSet?.id else { return }
        appState.removeRule(rule, from: setId)
    }

    @objc
    func addRule() {
        guard let setId = selectedSet?.id else { return }
        appState.addRule(addRuleField.stringValue, to: setId)
        addRuleField.stringValue = ""
    }

    @objc
    func toggleSuggestions() {
        isSuggestionsExpanded = RulesSheetActionsCoordinator.toggledSuggestions(
            isSuggestionsExpanded
        )
        if isSuggestionsExpanded {
            appState.refreshCurrentOpenUrls()
        }
        reloadRuleContent()
    }

    @objc
    func addSuggestion(_ sender: NSButton) {
        guard let url = sender.identifier?.rawValue, let setId = selectedSet?.id else { return }
        appState.addSpecificRule(url, to: setId)
    }

    @objc
    func handleDone() {
        onDismiss?()
    }
}
