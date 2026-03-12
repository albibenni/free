import Foundation

extension FocusSectionViewController {
    var headerStatusTextForTesting: String { headerStatusLabel.stringValue }
    var isPermissionWarningHiddenForTesting: Bool { permissionWarningView.isHidden }
    var isUnblockableWarningHiddenForTesting: Bool { unblockableWarningLabel.isHidden }
    var isPauseDashboardHiddenForTesting: Bool { pauseDashboardView.isHidden }
    var isQuickBreakDashboardHiddenForTesting: Bool { quickBreakDashboardView.isHidden }
    var pauseTimeTextForTesting: String { pauseTimeLabel.stringValue }
    var currentWidgetViewTypeForTesting: String? {
        widgetView.map { String(describing: type(of: $0)) }
    }
    var widgetViewIdentifierForTesting: ObjectIdentifier? {
        widgetView.map(ObjectIdentifier.init)
    }
    var pomodoroWidgetRefreshGenerationForTesting: Int? {
        (widgetView as? FocusPomodoroWidgetView)?.refreshGeneration
    }
    var hasDeferredPomodoroReloadForTesting: Bool {
        needsReloadAfterPomodoroInteraction
    }
    func beginPomodoroWidgetInteractionForTesting() {
        beginPomodoroWidgetInteraction()
    }
    func endPomodoroWidgetInteractionForTesting() {
        endPomodoroWidgetInteraction()
    }
    func simulateObservedAppStateChangeForTesting() {
        handleObservedAppStateChange()
    }
    func simulatePomodoroWidgetInteractionCallbacksForTesting() -> (didBegin: Bool, didEnd: Bool)? {
        (widgetView as? FocusPomodoroWidgetView)?.simulateDialInteractionCallbacksForTesting()
    }
}
