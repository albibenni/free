import AppKit

extension FocusSectionViewController {
    @objc
    func grantAccessibility() {
        grantAccessibilityActionFactory()()
    }

    @objc
    func cancelPause() {
        appState.cancelPause()
        needsReloadAfterPomodoroInteraction = false
        reloadContent()
    }
}
