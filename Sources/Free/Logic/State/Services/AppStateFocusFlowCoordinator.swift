import Foundation

enum AppStateFocusFlowCoordinator {
    enum SkipPhaseAction: Equatable {
        case startBreak
        case startFocus
        case none
    }

    enum PomodoroTickAction: Equatable {
        case decrement
        case startBreak
        case startFocus
    }

    struct PomodoroTransition: Equatable {
        let state: PomodoroEngine.State
        let shouldRunTimer: Bool
        let shouldStopTimer: Bool
        let shouldCheckSchedules: Bool
    }

    struct PauseTransition: Equatable {
        let state: PauseEngine.State
        let shouldStartTimer: Bool
        let shouldStopTimer: Bool
    }

    struct PauseTickTransition: Equatable {
        let state: PauseEngine.State
        let shouldCancelPause: Bool
    }

    static func startPomodoro(
        state: PomodoroEngine.State,
        focusDurationMinutes: Double,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet]
    ) -> PomodoroTransition {
        let updated = AppStatePomodoroCoordinator.startFocus(
            from: state,
            focusDurationMinutes: focusDurationMinutes,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets
        )
        return PomodoroTransition(
            state: updated,
            shouldRunTimer: true,
            shouldStopTimer: false,
            shouldCheckSchedules: false
        )
    }

    static func startBreak(
        state: PomodoroEngine.State,
        breakDurationMinutes: Double
    ) -> PomodoroTransition {
        let updated = AppStatePomodoroCoordinator.startBreak(
            from: state,
            breakDurationMinutes: breakDurationMinutes
        )
        return PomodoroTransition(
            state: updated,
            shouldRunTimer: true,
            shouldStopTimer: false,
            shouldCheckSchedules: false
        )
    }

    static func stopPomodoroIfUnlocked(
        state: PomodoroEngine.State,
        isLocked: Bool
    ) -> PomodoroTransition? {
        guard let stopped = AppStatePomodoroCoordinator.stopIfUnlocked(from: state, isLocked: isLocked)
        else { return nil }

        return PomodoroTransition(
            state: stopped,
            shouldRunTimer: false,
            shouldStopTimer: true,
            shouldCheckSchedules: true
        )
    }

    static func startPause(
        state: PauseEngine.State,
        minutes: Double,
        isBlocking: Bool
    ) -> PauseTransition? {
        guard
            let updated = AppStatePauseCoordinator.start(
                from: state,
                minutes: minutes,
                isBlocking: isBlocking
            )
        else { return nil }

        return PauseTransition(state: updated, shouldStartTimer: true, shouldStopTimer: false)
    }

    static func cancelPause(state: PauseEngine.State) -> PauseTransition {
        PauseTransition(
            state: AppStatePauseCoordinator.cancel(from: state),
            shouldStartTimer: false,
            shouldStopTimer: true
        )
    }

    static func skipPhaseAction(for status: PomodoroStatus) -> SkipPhaseAction {
        switch status {
        case .focus:
            return .startBreak
        case .breakTime:
            return .startFocus
        case .none:
            return .none
        }
    }

    static func pomodoroTickAction(
        status: PomodoroStatus,
        remaining: TimeInterval
    ) -> PomodoroTickAction {
        switch AppStateRuntimeCoordinator.pomodoroTickAction(status: status, remaining: remaining) {
        case .decrement:
            return .decrement
        case .startBreak:
            return .startBreak
        case .startFocus:
            return .startFocus
        }
    }

    static func pauseTick(state: PauseEngine.State) -> PauseTickTransition {
        let result = AppStateRuntimeCoordinator.pauseTick(from: state)
        return PauseTickTransition(state: result.state, shouldCancelPause: result.shouldCancel)
    }
}
