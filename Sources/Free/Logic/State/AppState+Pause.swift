import Foundation

extension AppState {
    private var pauseMutationContext: AppStatePauseMutationService.Context {
        AppStatePauseMutationService.Context(
            state: sessionDomainState.pauseEngineState,
            isBlocking: sessionDomainState.isBlocking
        )
    }

    func startPause(minutes: Double) {
        guard
            let transition = AppStatePauseMutationService.startPause(
                logicFacade: logicFacade,
                context: pauseMutationContext,
                minutes: minutes
            )
        else { return }
        applyPauseEngineState(transition.state)
        if transition.shouldStartTimer {
            let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
                guard let self = self else { return }
                let result = AppStatePauseMutationService.pauseTick(
                    logicFacade: self.logicFacade,
                    state: self.sessionDomainState.pauseEngineState
                )
                self.applyPauseEngineState(result.state)
                if result.shouldCancelPause {
                    self.cancelPause()
                }
            }
            timerCoordinator.replacePauseTimer(with: timer)
        }
    }

    func cancelPause() {
        let transition = AppStatePauseMutationService.cancelPause(
            logicFacade: logicFacade,
            state: sessionDomainState.pauseEngineState
        )
        applyPauseEngineState(transition.state)
        if transition.shouldStopTimer {
            timerCoordinator.replacePauseTimer(with: nil)
        }
        if transition.shouldCheckSchedules {
            checkSchedules()
        }
    }
}
