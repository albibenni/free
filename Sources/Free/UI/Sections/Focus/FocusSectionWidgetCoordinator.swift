import Foundation

@MainActor
enum FocusSectionWidgetCoordinator {
    enum PomodoroReuseAction {
        case updateSelection
        case refresh
        case keepLayout
    }

    static func pomodoroReuseAction(
        current: FocusPomodoroWidgetSignature?,
        next: FocusPomodoroWidgetSignature
    ) -> PomodoroReuseAction {
        guard let current else {
            return .refresh
        }

        if current.contentSignature == next.contentSignature,
           current.activeRuleSetId != next.activeRuleSetId
            || current.currentPrimaryRuleSetId != next.currentPrimaryRuleSetId
        {
            return .updateSelection
        }

        if current != next {
            return .refresh
        }

        return .keepLayout
    }
}
