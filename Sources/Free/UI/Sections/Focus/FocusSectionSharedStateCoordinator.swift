import AppKit

@MainActor
enum FocusSectionSharedStateCoordinator {
    struct Presentation {
        let isPermissionWarningHidden: Bool
        let focusIconColor: NSColor
        let headerStatusText: String
        let isStrictWarningHidden: Bool
        let isPauseDashboardHidden: Bool
        let pauseTimeText: String
    }

    static func makePresentation(appState: AppState) -> Presentation {
        let isBlocking = appState.isBlocking
        let isPaused = appState.isPaused
        let status = FocusSectionSupport.statusLabel(
            isBlocking: isBlocking,
            isPaused: isPaused
        )
        let headerStatusText: String
        if FocusSectionSupport.shouldShowRuleSetName(
            isBlocking: isBlocking,
            isPaused: isPaused
        ) {
            headerStatusText = "\(status) • \(appState.currentPrimaryRuleSetName)"
        } else {
            headerStatusText = status
        }

        return Presentation(
            isPermissionWarningHidden: appState.isTrusted,
            focusIconColor: FocusSectionSupport.focusIconColor(
                isBlocking: isBlocking,
                isPaused: isPaused
            ),
            headerStatusText: headerStatusText,
            isStrictWarningHidden: !FocusSectionSupport.shouldShowStrictWarning(
                isBlocking: isBlocking,
                isStrict: appState.isStrict
            ),
            isPauseDashboardHidden: !FocusSectionSupport.shouldShowPauseDashboard(
                isBlocking: isBlocking,
                isPaused: isPaused
            ),
            pauseTimeText: appState.timeString(time: appState.pauseRemaining)
        )
    }
}
