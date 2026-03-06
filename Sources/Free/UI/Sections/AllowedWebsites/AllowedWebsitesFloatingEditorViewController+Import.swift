import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    @objc
    func handleImportOpenTabs() {
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        guard let selectedSet = appState.ruleSets.first(where: { $0.id == setId }) else { return }

        appState.refreshCurrentOpenUrls()
        let candidates = AllowedWebsitesImportCoordinator.buildCandidates(
            currentOpenUrls: appState.currentOpenUrls,
            selectedSet: selectedSet
        )

        guard !candidates.isEmpty else {
            AllowedWebsitesImportAlertPresenter.presentEmptyState(
                currentOpenUrls: appState.currentOpenUrls
            )
            return
        }

        guard let selectedRules = AllowedWebsitesImportAlertPresenter.presentCandidateSelection(
            candidates: candidates,
            selectedSetName: selectedSet.name
        ) else { return }

        for rule in selectedRules {
            appState.addSpecificRule(rule, to: setId)
        }
        reloadRulesOnly()
    }
}
