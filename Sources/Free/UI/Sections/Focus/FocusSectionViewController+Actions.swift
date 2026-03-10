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

    func startQuickBreak(minutes: Double) {
        appState.startPause(minutes: minutes)
        needsReloadAfterPomodoroInteraction = false
        reloadContent()
    }

    func startCustomQuickBreak() {
        guard let minutes = Double(quickBreakCustomMinutesField.stringValue) else { return }
        startQuickBreak(minutes: minutes)
    }
}
