import AppKit

extension FocusSectionViewController {
    func handleObservedAppStateChange() {
        let action = FocusSectionObservedChangeCoordinator.action(
            section: section,
            interactionDepth: pomodoroWidgetInteractionDepth,
            widgetKind: FocusSectionWidgetReloadCoordinator.widgetKind(for: widgetView),
            hasPomodoroSignature: pomodoroWidgetSignature != nil
        )
        switch action {
        case .deferReload:
            needsReloadAfterPomodoroInteraction = true
        case .updatePomodoroWidget:
            guard let pomodoroWidgetView = widgetView as? FocusPomodoroWidgetView else { return }
            pomodoroWidgetSignature = FocusPomodoroWidgetSignature(appState: appState)
            applySharedState()
            pomodoroWidgetView.updateRuleSetSelection()
            pomodoroWidgetView.updateForStateChange()
            // Pause dashboard visibility can change while reusing pomodoro widget; force a layout pass
            // so stack hit regions update immediately.
            scrollContainer.needsLayout = true
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
        case .reloadContent:
            reloadContent()
        }
    }

    func applySharedState() {
        let sharedState = FocusSectionSharedStateCoordinator.makePresentation(appState: appState)

        permissionWarningView.isHidden = sharedState.isPermissionWarningHidden

        let headerIconName = AppKitUISymbols.Name.focus
        headerIconView.image = NSImage(
            systemSymbolName: headerIconName,
            accessibilityDescription: nil
        )
        headerIconView.contentTintColor = sharedState.focusIconColor
        headerStatusLabel.stringValue = sharedState.headerStatusText

        unblockableWarningLabel.font = .systemFont(ofSize: 12)
        unblockableWarningLabel.textColor = .systemOrange
        unblockableWarningLabel.isHidden = sharedState.isUnblockableWarningHidden

        pauseDashboardView.isHidden = sharedState.isPauseDashboardHidden
        pauseTimeLabel.stringValue = sharedState.pauseTimeText
    }

    func beginPomodoroWidgetInteraction() {
        pomodoroWidgetInteractionDepth += 1
    }

    func endPomodoroWidgetInteraction() {
        guard pomodoroWidgetInteractionDepth > 0 else { return }
        pomodoroWidgetInteractionDepth -= 1

        guard FocusInteractionReloadCoordinator.shouldFlushDeferredReload(
            interactionDepth: pomodoroWidgetInteractionDepth,
            needsReloadAfterInteraction: needsReloadAfterPomodoroInteraction
        ) else { return }

        needsReloadAfterPomodoroInteraction = false
        handleObservedAppStateChange()
    }
}
