import AppKit

extension FocusSectionViewController {
    @objc
    func grantAccessibility() {
        guard appState.usesAccessibilityEngine else {
            // v2 — content-filter build.
            switch appState.filterStatus {
            case .failed:
                // Nothing to approve yet (activation never registered): retry it.
                appState.onFilterRetry?()
            default:
                // Waiting for approval / installing: point the user at Settings.
                FocusSectionSupport.openSystemExtensionSettings()
            }
            return
        }
        if let monitor = appState.monitor {
            Task { await monitor.checkPermissions(prompt: true) }
        } else {
            grantAccessibilityActionFactory()()
        }
    }

    @objc
    func cancelPause() {
        appState.cancelPause()
        needsReloadAfterPomodoroInteraction = false
        reloadContent()
    }

    func startQuickBreak(minutes: Double) {
        if appState.isStrict {
            guard StrictModeChallenge.run(
                title: "Quick Break",
                action: "start a quick break",
                appState: appState
            ) else { return }
        }
        appState.startPause(minutes: minutes)
        needsReloadAfterPomodoroInteraction = false
        reloadContent()
    }

    func startCustomQuickBreak() {
        guard let minutes = Double(quickBreakCustomMinutesField.stringValue) else { return }
        startQuickBreak(minutes: minutes)
    }
}

extension FocusSectionViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === quickBreakCustomMinutesField else {
            return
        }
        let digitsOnly = field.stringValue.filter(\.isNumber)
        field.stringValue = String(digitsOnly.prefix(3))
    }
}
