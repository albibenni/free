import AppKit

extension FocusSectionViewController {
    func reloadContent() {
        applySharedState()

        let visibility = FocusSectionVisibilityCoordinator.visibility(for: section)
        overviewCardView.isHidden = !visibility.shouldShowOverview
        if visibility.shouldShowOverview {
            reloadOverviewRows()
        }
        reloadWidget()
        scrollContainer.needsLayout = true
    }

    func reloadOverviewRows() {
        let renderModel = FocusSectionOverviewRenderCoordinator.renderModel(appState: appState)
        FocusSectionOverviewViewApplier.apply(
            renderModel: renderModel,
            to: overviewRowsStack,
            accentColorIndex: appState.accentColorIndex,
            availableWidth: scrollContainer.stackView.bounds.width
        )
    }
}
