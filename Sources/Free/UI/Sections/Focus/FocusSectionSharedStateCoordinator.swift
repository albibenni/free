import AppKit

@MainActor
enum FocusSectionSharedStateCoordinator {
    struct Presentation {
        let isPermissionWarningHidden: Bool
        let permissionWarningText: String
        let permissionActionTitle: String
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

        let permissionWarningHidden: Bool
        let permissionWarningText: String
        let permissionActionTitle: String
        if appState.usesAccessibilityEngine {
            // v1 — Accessibility engine
            permissionWarningHidden = appState.isTrusted
            permissionWarningText = "Accessibility Permission Needed"
            permissionActionTitle = "Grant"
        } else {
            // v2 — content-filter extension
            switch appState.filterStatus {
            case .active:
                permissionWarningHidden = true
                permissionWarningText = ""
                permissionActionTitle = "Open Settings"
            case .needsApproval:
                permissionWarningHidden = false
                permissionWarningText = "Approve “Free” in System Settings › Network Extensions"
                permissionActionTitle = "Open Settings"
            case .installing:
                permissionWarningHidden = false
                permissionWarningText = "Setting up content filter…"
                permissionActionTitle = "Open Settings"
            case .failed:
                permissionWarningHidden = false
                permissionWarningText = "Content filter couldn’t start"
                permissionActionTitle = "Retry"
            }
        }

        return Presentation(
            isPermissionWarningHidden: permissionWarningHidden,
            permissionWarningText: permissionWarningText,
            permissionActionTitle: permissionActionTitle,
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
