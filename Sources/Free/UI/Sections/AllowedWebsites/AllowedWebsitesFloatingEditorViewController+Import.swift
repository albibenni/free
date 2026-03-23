import AppKit

extension AllowedWebsitesFloatingEditorViewController {
    typealias EmptyImportStatePresenter = ([String]) -> Void
    typealias ImportCandidatesPresenter = ([AllowedWebsitesImportCoordinator.Candidate], String) -> [String]?

    private static var customPresentEmptyImportState: EmptyImportStatePresenter?
    private static var customPresentImportCandidates: ImportCandidatesPresenter?

    static var presentEmptyImportState: EmptyImportStatePresenter {
        get { customPresentEmptyImportState ?? defaultPresentEmptyImportState }
        set { customPresentEmptyImportState = newValue }
    }

    static var presentImportCandidates: ImportCandidatesPresenter {
        get { customPresentImportCandidates ?? defaultPresentImportCandidates }
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

    static func resetImportPresentersForTesting() {
        customPresentEmptyImportState = nil
        customPresentImportCandidates = nil
    }

    @objc
    func handleImportOpenTabs() {
        guard !isAllowedWebsitesEditingLocked else { return }
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
