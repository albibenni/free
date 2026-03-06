import Foundation

struct AppStatePomodoroCoordinator {
    enum TimerAction: Equatable {
        case decrement
        case startBreak
        case startFocus
    }

    static func startFocus(
        from state: PomodoroEngine.State,
        focusDurationMinutes: Double,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet]
    ) -> PomodoroEngine.State {
        PomodoroEngine.startFocus(
            from: state,
            focusDurationMinutes: focusDurationMinutes,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets
        )
    }

    static func startBreak(
        from state: PomodoroEngine.State,
        breakDurationMinutes: Double
    ) -> PomodoroEngine.State {
        PomodoroEngine.startBreak(
            from: state,
            breakDurationMinutes: breakDurationMinutes
        )
    }

    static func stopIfUnlocked(
        from state: PomodoroEngine.State,
        isLocked: Bool
    ) -> PomodoroEngine.State? {
        guard !isLocked else { return nil }
        return PomodoroEngine.stop(from: state)
    }

    static func timerAction(status: AppState.PomodoroStatus, remaining: TimeInterval) -> TimerAction {
        if remaining > 0 { return .decrement }
        return status == .focus ? .startBreak : .startFocus
    }
}
