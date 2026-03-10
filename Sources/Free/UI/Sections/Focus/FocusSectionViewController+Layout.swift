import AppKit

extension FocusSectionViewController {
    func configurePermissionWarning() {
        FocusSectionLayoutBuilder.configurePermissionWarning(
            permissionWarningView: permissionWarningView,
            permissionTitleLabel: permissionTitleLabel,
            grantPermissionButton: grantPermissionButton,
            target: self,
            grantAction: #selector(grantAccessibility)
        )
    }

    func configureHeaderCard() {
        FocusSectionLayoutBuilder.configureHeaderCard(
            headerCardView: headerCardView,
            headerIconView: headerIconView,
            headerTitleLabel: headerTitleLabel,
            headerStatusLabel: headerStatusLabel
        )
    }

    func configurePauseDashboard() {
        FocusSectionLayoutBuilder.configurePauseDashboard(
            pauseDashboardView: pauseDashboardView,
            pauseTitleLabel: pauseTitleLabel,
            pauseTimeLabel: pauseTimeLabel,
            pauseEndButton: pauseEndButton,
            horizontalOffset: section == .pomodoro ? 56 : 0,
            cancelAction: { [weak self] in
                self?.cancelPause()
            }
        )
    }

    func configureQuickBreakDashboard() {
        quickBreakCustomMinutesField.delegate = self
        FocusSectionLayoutBuilder.configureQuickBreakDashboard(
            quickBreakDashboardView: quickBreakDashboardView,
            quickBreakTitleLabel: quickBreakTitleLabel,
            quickBreakFiveButton: quickBreakFiveButton,
            quickBreakFifteenButton: quickBreakFifteenButton,
            quickBreakThirtyButton: quickBreakThirtyButton,
            quickBreakCustomMinutesField: quickBreakCustomMinutesField,
            quickBreakCustomButton: quickBreakCustomButton,
            startBreak: { [weak self] minutes in
                self?.startQuickBreak(minutes: minutes)
            },
            startCustomBreak: { [weak self] in
                self?.startCustomQuickBreak()
            }
        )
    }

    func configureOverview() {
        FocusSectionLayoutBuilder.configureOverview(
            overviewCardView: overviewCardView,
            overviewTitleLabel: overviewTitleLabel,
            overviewRowsStack: overviewRowsStack
        )
    }

    func configureWidgetContainer() {
        widgetContainer.translatesAutoresizingMaskIntoConstraints = false
    }
}
