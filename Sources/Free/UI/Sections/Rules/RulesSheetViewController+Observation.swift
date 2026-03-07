import AppKit

extension RulesSheetViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        AppKitAppStateObservation.bind(
            publisher: AppKitAppStateObservation.rulesPublisher(appState: appState),
            signature: { [weak self, appState] in
                guard let self else {
                    return RulesSheetRenderSignature(
                        appState: appState,
                        isSuggestionsExpanded: false,
                        currentSelectedSetId: nil
                    )
                }
                return self.currentRenderSignature()
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
