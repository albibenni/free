import AppKit

enum FocusSectionWidgetHostApplier {
    static func applyPomodoroReuse(
        action: FocusSectionWidgetCoordinator.PomodoroReuseAction,
        widgetView: NSView?,
        widgetContainer: NSView
    ) {
        guard let pomodoroWidgetView = widgetView as? FocusPomodoroWidgetView else { return }
        widgetContainer.isHidden = false
        switch action {
        case .updateSelection:
            pomodoroWidgetView.updateRuleSetSelection()
        case .refresh:
            pomodoroWidgetView.refreshForStateChange()
        case .keepLayout:
            pomodoroWidgetView.needsLayout = true
        }
    }

    static func applyKeepExisting(
        isContainerHidden: Bool,
        widgetContainer: NSView
    ) {
        widgetContainer.isHidden = isContainerHidden
    }

    static func applyRebuild(
        buildResult: FocusSectionWidgetFactory.BuildResult,
        currentWidgetView: NSView?,
        widgetContainer: NSView,
        isContainerHidden: Bool
    ) -> NSView? {
        currentWidgetView?.removeFromSuperview()
        widgetContainer.isHidden = isContainerHidden
        guard let nextWidgetView = buildResult.widgetView else {
            return nil
        }

        nextWidgetView.translatesAutoresizingMaskIntoConstraints = false
        widgetContainer.addSubview(nextWidgetView)
        NSLayoutConstraint.activate([
            nextWidgetView.leadingAnchor.constraint(equalTo: widgetContainer.leadingAnchor),
            nextWidgetView.trailingAnchor.constraint(equalTo: widgetContainer.trailingAnchor),
            nextWidgetView.topAnchor.constraint(equalTo: widgetContainer.topAnchor),
            nextWidgetView.bottomAnchor.constraint(equalTo: widgetContainer.bottomAnchor),
        ])
        return nextWidgetView
    }
}
