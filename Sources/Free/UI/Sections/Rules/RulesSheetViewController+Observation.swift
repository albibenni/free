import AppKit

extension RulesSheetViewController {
    static func observationSignature(
        controller: RulesSheetViewController?,
        appState: AppState
    ) -> RulesSheetRenderSignature {
        guard let controller else {
            return RulesSheetRenderSignature(
                appState: appState,
                isSuggestionsExpanded: false,
                currentSelectedSetId: nil
            )
        }
        return controller.currentRenderSignature()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppKitAppStateObservation.bind(
            publisher: AppKitAppStateObservation.rulesPublisher(appState: appState),
            signature: { [weak self, appState] in
                RulesSheetViewController.observationSignature(
                    controller: self,
                    appState: appState
                )
            },
            cancellables: &cancellables
        ) { [weak self] _ in
            self?.reloadContent()
        }

        appState.refreshCurrentOpenUrls()
        reloadContent()
    }

    func currentRenderSignature() -> RulesSheetRenderSignature {
        RulesSheetRenderSignature(
            appState: appState,
            isSuggestionsExpanded: isSuggestionsExpanded,
            currentSelectedSetId: selectedSetId
        )
    }
}
