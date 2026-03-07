import AppKit

extension FocusSectionViewController {
    func reloadWidget() {
        let visibility = FocusSectionVisibilityCoordinator.visibility(for: section)
        let decision = FocusSectionWidgetReloadCoordinator.decide(
            section: section,
            appState: appState,
            shellState: shellState,
            currentWidgetKind: FocusSectionWidgetReloadCoordinator.widgetKind(for: widgetView),
            currentSignatures: FocusSectionWidgetReloadCoordinator.Signatures(
                pomodoro: pomodoroWidgetSignature,
                schedules: schedulesWidgetSignature,
                allowedWebsites: allowedWebsitesWidgetSignature
            ),
            onPomodoroInteractionDidBegin: { [weak self] in self?.beginPomodoroWidgetInteraction() },
            onPomodoroInteractionDidEnd: { [weak self] in self?.endPomodoroWidgetInteraction() }
        )

        pomodoroWidgetSignature = decision.signatures.pomodoro
        schedulesWidgetSignature = decision.signatures.schedules
        allowedWebsitesWidgetSignature = decision.signatures.allowedWebsites

        switch decision.operation {
        case .reusePomodoro(let action):
            FocusSectionWidgetHostApplier.applyPomodoroReuse(
                action: action,
                widgetView: widgetView,
                widgetContainer: widgetContainer
            )
            return
        case .keepExisting:
            FocusSectionWidgetHostApplier.applyKeepExisting(
                isContainerHidden: visibility.isWidgetContainerHidden,
                widgetContainer: widgetContainer
            )
            return
        case .rebuild(let buildResult):
            widgetView = FocusSectionWidgetHostApplier.applyRebuild(
                buildResult: buildResult,
                currentWidgetView: widgetView,
                widgetContainer: widgetContainer,
                isContainerHidden: visibility.isWidgetContainerHidden
            )
        }
    }
}
