import Foundation

extension AppState {
    private func applyPomodoroTransition(
        _ transition: AppStateLogicFacade.PomodoroTransition
    ) {
        applyPomodoroEngineState(transition.state)
        if transition.shouldStopTimer {
            timerCoordinator.replacePomodoroTimer(with: nil)
        }
        if transition.shouldRunTimer {
            runPomodoroTimer()
        }
        if transition.shouldCheckSchedules {
            checkSchedules()
        }
    }

    func startPomodoro() {
        applyPomodoroTransition(
            logicFacade.startPomodoro(
                state: pomodoroEngineState,
                focusDurationMinutes: pomodoroFocusDuration,
                activeRuleSetId: activeRuleSetId,
                ruleSets: ruleSets
            )
        )
    }

    /// `bypassingStrictLock` is only for callers that have already passed the
    /// strict-mode challenge; it avoids round-tripping `isStrict` through
    /// persisted state to unlock the stop.
    func stopPomodoro(bypassingStrictLock: Bool = false) {
        guard
            let transition = logicFacade.stopPomodoroIfUnlocked(
                state: pomodoroEngineState,
                isLocked: bypassingStrictLock ? false : isPomodoroLocked
            )
        else { return }
        applyPomodoroTransition(transition)
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
        applyPomodoroTransition(
            logicFacade.startBreak(
                state: pomodoroEngineState,
                breakDurationMinutes: pomodoroBreakDuration
            )
        )
    }

    private func runPomodoroTimer() {
        let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
            guard let self = self else { return }
            guard !self.isPaused else { return }
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
