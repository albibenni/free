import Foundation

extension AppState {
    func startPomodoro() {
        let transition = logicFacade.startPomodoro(
            state: pomodoroEngineState,
            focusDurationMinutes: pomodoroFocusDuration,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets
        )
        applyPomodoroEngineState(transition.state)
        if transition.shouldRunTimer {
            runPomodoroTimer()
        }
    }

    func stopPomodoro() {
        guard
            let transition = logicFacade.stopPomodoroIfUnlocked(
                state: pomodoroEngineState,
                isLocked: isPomodoroLocked
            )
        else { return }
        applyPomodoroEngineState(transition.state)
        if transition.shouldStopTimer {
            timerCoordinator.replacePomodoroTimer(with: nil)
        }
        if transition.shouldCheckSchedules {
            checkSchedules()
        }
    }

    func skipPomodoroPhase() {
        switch logicFacade.skipPhaseAction(for: pomodoroStatus) {
        case .startBreak:
            startBreak()
        case .startFocus:
            startPomodoro()
        case .none:
            break
        }
    }

    private func startBreak() {
        let transition = logicFacade.startBreak(
            state: pomodoroEngineState,
            breakDurationMinutes: pomodoroBreakDuration
        )
        applyPomodoroEngineState(transition.state)
        if transition.shouldRunTimer {
            runPomodoroTimer()
        }
    }

    private func runPomodoroTimer() {
        let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
            guard let self = self else { return }
            switch self.logicFacade.pomodoroTickAction(
                status: self.pomodoroStatus,
                remaining: self.pomodoroRemaining
            ) {
            case .decrement:
                self.pomodoroRemaining -= 1
            case .startBreak:
                self.startBreak()
            case .startFocus:
                self.startPomodoro()
            }
        }
        timerCoordinator.replacePomodoroTimer(with: timer)
        checkSchedules()
    }
}
