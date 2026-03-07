import Foundation

extension AppState {
    var pomodoroEngineState: PomodoroEngine.State {
        pomodoroDomainState.pomodoroEngineState
    }

    func applyPomodoroEngineState(_ state: PomodoroEngine.State) {
        var domainState = pomodoroDomainState
        domainState.status = state.status
        domainState.remaining = state.remaining
        domainState.startedAt = state.startedAt
        domainState.ruleSetId = state.ruleSetId
        applyPomodoroDomainState(domainState)
    }

    var pomodoroDomainState: AppPomodoroDomainState {
        AppPomodoroDomainState(
            status: pomodoroStatus,
            remaining: pomodoroRemaining,
            startedAt: pomodoroStartedAt,
            focusDurationMinutes: pomodoroFocusDuration,
            breakDurationMinutes: pomodoroBreakDuration,
            ruleSetId: pomodoroRuleSetId
        )
    }

    func applyPomodoroDomainState(_ state: AppPomodoroDomainState) {
        if pomodoroStatus != state.status { pomodoroStatus = state.status }
        if pomodoroRemaining != state.remaining { pomodoroRemaining = state.remaining }
        if pomodoroStartedAt != state.startedAt { pomodoroStartedAt = state.startedAt }
        if pomodoroFocusDuration != state.focusDurationMinutes {
            pomodoroFocusDuration = state.focusDurationMinutes
        }
        if pomodoroBreakDuration != state.breakDurationMinutes {
            pomodoroBreakDuration = state.breakDurationMinutes
        }
        if pomodoroRuleSetId != state.ruleSetId { pomodoroRuleSetId = state.ruleSetId }
    }
}
