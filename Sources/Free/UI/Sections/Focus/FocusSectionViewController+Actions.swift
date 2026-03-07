import AppKit

extension FocusSectionViewController {
    @objc
    func grantAccessibility() {
        FocusSectionSupport.makeGrantAccessibilityAction()()
    }

    @objc
    func cancelPause() {
        appState.cancelPause()
        needsReloadAfterPomodoroInteraction = false
        reloadContent()
    }
}
