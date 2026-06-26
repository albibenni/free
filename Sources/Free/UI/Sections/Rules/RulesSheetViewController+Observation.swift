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
        AppKitAppStateObservation.observe(
            appState: appState,
            signature: { [weak self, weak appState] () -> RulesSheetRenderSignature? in
                guard let self = self, let appState = appState else { return nil }
                return RulesSheetViewController.observationSignature(
                    controller: self,
                    appState: appState
                )
            }
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
