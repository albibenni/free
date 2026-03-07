import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    typealias EmptyImportStatePresenter = ([String]) -> Void
    typealias ImportCandidatesPresenter = ([AllowedWebsitesImportCoordinator.Candidate], String) -> [String]?

    static var presentEmptyImportState: EmptyImportStatePresenter = { currentOpenUrls in
        AllowedWebsitesImportAlertPresenter.presentEmptyState(currentOpenUrls: currentOpenUrls)
    }

    static var presentImportCandidates: ImportCandidatesPresenter = { candidates, selectedSetName in
        AllowedWebsitesImportAlertPresenter.presentCandidateSelection(
            candidates: candidates,
            selectedSetName: selectedSetName
        )
    }

    static func resetImportPresentersForTesting() {
        presentEmptyImportState = { currentOpenUrls in
            AllowedWebsitesImportAlertPresenter.presentEmptyState(currentOpenUrls: currentOpenUrls)
        }
        presentImportCandidates = { candidates, selectedSetName in
            AllowedWebsitesImportAlertPresenter.presentCandidateSelection(
                candidates: candidates,
                selectedSetName: selectedSetName
            )
        }
    }

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
            Self.presentEmptyImportState(appState.currentOpenUrls)
            return
        }

        guard let selectedRules = Self.presentImportCandidates(candidates, selectedSet.name) else { return }

        for rule in selectedRules {
            appState.addSpecificRule(rule, to: setId)
        }
        reloadRulesOnly()
    }
}
