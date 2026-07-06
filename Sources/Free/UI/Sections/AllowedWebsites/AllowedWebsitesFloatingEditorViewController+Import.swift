import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    typealias EmptyImportStatePresenter = ([String]) -> Void
    typealias ImportCandidatesPresenter = ([AllowedWebsitesImportCoordinator.Candidate], String) -> [String]?

    var presentEmptyImportState: EmptyImportStatePresenter {
        get { customPresentEmptyImportState ?? Self.defaultPresentEmptyImportState }
        set { customPresentEmptyImportState = newValue }
    }

    var presentImportCandidates: ImportCandidatesPresenter {
        get { customPresentImportCandidates ?? Self.defaultPresentImportCandidates }
        set { customPresentImportCandidates = newValue }
    }

    private static func defaultPresentEmptyImportState(currentOpenUrls: [String]) {
        AllowedWebsitesImportAlertPresenter.presentEmptyState(currentOpenUrls: currentOpenUrls)
    }

    private static func defaultPresentImportCandidates(
        candidates: [AllowedWebsitesImportCoordinator.Candidate],
        selectedSetName: String
    ) -> [String]? {
        AllowedWebsitesImportAlertPresenter.presentCandidateSelection(
            candidates: candidates,
            selectedSetName: selectedSetName
        )
    }

    func resetImportPresentersForTesting() {
        customPresentEmptyImportState = nil
        customPresentImportCandidates = nil
    }

    @objc
    func handleImportOpenTabs() {
        Task { @MainActor in
            await handleImportOpenTabsAsync()
        }
    }

    func handleImportOpenTabsAsync() async {
        guard let setId = resolvedRuleSetId(selectedRuleSetId) else { return }
        guard let selectedSet = appState.ruleSets.first(where: { $0.id == setId }) else { return }

        await appState.refreshCurrentOpenUrlsAsync()
        let candidates = AllowedWebsitesImportCoordinator.buildCandidates(
            currentOpenUrls: appState.currentOpenUrls,
            selectedSet: selectedSet
        )

        guard !candidates.isEmpty else {
            presentEmptyImportState(appState.currentOpenUrls)
            return
        }

        guard let selectedRules = presentImportCandidates(candidates, selectedSet.name),
              !selectedRules.isEmpty else { return }

        if isAllowedWebsitesEditingLocked {
            guard StrictModeChallenge.run(
                title: "Import Open Tabs",
                action: "add the selected URLs to the allowed list",
                appState: appState
            ) else { return }
        }

        for rule in selectedRules {
            appState.addSpecificRule(rule, to: setId)
        }
        reloadRulesOnly()
    }
}
