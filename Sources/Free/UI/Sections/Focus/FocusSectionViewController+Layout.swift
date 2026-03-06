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
            target: self,
            cancelAction: #selector(cancelPause)
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
