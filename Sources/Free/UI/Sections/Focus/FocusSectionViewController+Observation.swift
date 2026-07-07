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
            // The coordinator emits .updatePomodoroWidget only when widgetKind is .pomodoro.
            // Keep this path branch-free for deterministic observation coverage.
            let pomodoroWidgetView = widgetView as! FocusPomodoroWidgetView
            pomodoroWidgetSignature = FocusPomodoroWidgetSignature(appState: appState)
            applySharedState()
            pomodoroWidgetView.updateRuleSetSelection()
            pomodoroWidgetView.updateForStateChange()
            // Pause dashboard visibility can change while reusing pomodoro widget; force a layout pass
            // without synchronously flushing layout on every observed tick.
            scrollContainer.needsLayout = true
            view.needsLayout = true
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
        headerFocusedValueLabel.stringValue = sharedState.focusedTodayText

        strictWarningLabel.font = .systemFont(ofSize: 12)
        strictWarningLabel.textColor = .systemOrange
        strictWarningLabel.stringValue = FocusSectionSupport.strictWarningText(for: section)
        strictWarningLabel.isHidden = sharedState.isStrictWarningHidden

        pauseDashboardView.isHidden = sharedState.isPauseDashboardHidden
        pauseTimeLabel.stringValue = sharedState.pauseTimeText

        let quickBreakEnabled =
            appState.isBlocking
            && !appState.isPaused
        [quickBreakFiveButton, quickBreakFifteenButton, quickBreakThirtyButton, quickBreakCustomButton].forEach {
            $0.isEnabled = quickBreakEnabled
        }
        quickBreakCustomMinutesField.isEnabled = quickBreakEnabled
        quickBreakCustomMinutesField.isEditable = quickBreakEnabled
        applyQuickBreakFieldStateAppearance(isEnabled: quickBreakEnabled)
        quickBreakDashboardView.isHidden = section != .all || appState.isPaused
    }

    private func applyQuickBreakFieldStateAppearance(isEnabled: Bool) {
        if isEnabled {
            applyAppKitInputFieldStyle(
                quickBreakCustomMinutesField,
                backgroundOpacity: 0.56,
                borderOpacity: 0.60,
                textOpacity: 0.80
            )
        } else {
            applyAppKitInputFieldStyle(
                quickBreakCustomMinutesField,
                backgroundOpacity: 0.28,
                borderOpacity: 0.30,
                textOpacity: 0.58
            )
            // Match disabled pill/button neutral tone more closely.
            quickBreakCustomMinutesField.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08)
            quickBreakCustomMinutesField.layer?.borderColor =
                NSColor.separatorColor.withAlphaComponent(0.30).cgColor
            quickBreakCustomMinutesField.textColor =
                NSColor.tertiaryLabelColor.withAlphaComponent(0.95)
        }
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
