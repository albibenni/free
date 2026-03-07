import Foundation

enum FocusSectionObservedChangeCoordinator {
    enum Action: Equatable {
        case deferReload
        case updatePomodoroWidget
        case reloadContent
    }

    static func action(
        section: FocusContentSection,
        interactionDepth: Int,
        widgetKind: FocusSectionWidgetReloadCoordinator.WidgetKind,
        hasPomodoroSignature: Bool
    ) -> Action {
        if FocusInteractionReloadCoordinator.shouldDeferObservedChange(
            section: section,
            interactionDepth: interactionDepth
        ) {
            return .deferReload
        }

        if section == .pomodoro,
           widgetKind == .pomodoro,
           hasPomodoroSignature
        {
            return .updatePomodoroWidget
        }

        return .reloadContent
    }
}
