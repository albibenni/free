import Foundation

enum AllowedWebsitesReloadCoordinator {
    struct ReloadState {
        let renderSignature: AllowedWebsitesFloatingEditorViewController.RenderSignature
        let selectedRuleSetId: UUID?
    }

    static func renderSignature(
        appState: AppState
    ) -> AllowedWebsitesFloatingEditorViewController.RenderSignature {
        AllowedWebsitesFloatingEditorViewController.RenderSignature(
            ruleSets: appState.ruleSets,
            activeRuleSetId: appState.activeRuleSetId,
            isStrict: appState.isStrict,
            accentColorIndex: appState.accentColorIndex
        )
    }

    static func reloadState(
        appState: AppState,
        previousSelectedRuleSetId: UUID?
    ) -> ReloadState {
        ReloadState(
            renderSignature: renderSignature(appState: appState),
            selectedRuleSetId: AllowedWebsitesSelectionCoordinator.resolvedRuleSetId(
                previousSelectedRuleSetId,
                ruleSets: appState.ruleSets,
                activeRuleSetId: appState.activeRuleSetId
            )
        )
    }
}
