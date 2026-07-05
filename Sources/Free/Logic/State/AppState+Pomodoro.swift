import Foundation

extension AppState {
    private var pomodoroMutationContext: AppStatePomodoroMutationService.Context {
        pomodoroMutationContext(isLocked: isPomodoroLocked)
    }

    private func pomodoroMutationContext(isLocked: Bool) -> AppStatePomodoroMutationService.Context {
        AppStatePomodoroMutationService.Context(
            state: pomodoroEngineState,
            status: pomodoroStatus,
            remaining: pomodoroRemaining,
            focusDurationMinutes: pomodoroFocusDuration,
            breakDurationMinutes: pomodoroBreakDuration,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets,
            isLocked: isLocked
        )
    }

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
        let transition = AppStatePomodoroMutationService.startPomodoro(
            logicFacade: logicFacade,
            context: pomodoroMutationContext
        )
        applyPomodoroTransition(transition)
    }

    /// `bypassingStrictLock` is only for callers that have already passed the
    /// strict-mode challenge; it avoids round-tripping `isStrict` through
    /// persisted state to unlock the stop.
    func stopPomodoro(bypassingStrictLock: Bool = false) {
        guard
            let transition = AppStatePomodoroMutationService.stopPomodoroIfUnlocked(
                logicFacade: logicFacade,
                context: pomodoroMutationContext(isLocked: bypassingStrictLock ? false : isPomodoroLocked)
            )
        else { return }
        applyPomodoroTransition(transition)
    }

    func skipPomodoroPhase() {
        switch AppStatePomodoroMutationService.skipPhaseAction(
            logicFacade: logicFacade,
            status: pomodoroStatus
        ) {
        case .startBreak:
            startBreak()
        case .startFocus:
            startPomodoro()
        case .none:
            break
        }
    }

    private func startBreak() {
        let transition = AppStatePomodoroMutationService.startBreak(
            logicFacade: logicFacade,
            context: pomodoroMutationContext
        )
        applyPomodoroTransition(transition)
    }

    private func runPomodoroTimer() {
        let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
            guard let self = self else { return }
            guard !self.isPaused else { return }
            switch AppStatePomodoroMutationService.tickAction(
                logicFacade: self.logicFacade,
                context: self.pomodoroMutationContext
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
