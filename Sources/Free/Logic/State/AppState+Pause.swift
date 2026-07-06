import Foundation

extension AppState {
    func startPause(minutes: Double) {
        guard
            let transition = logicFacade.startPause(
                state: sessionDomainState.pauseEngineState,
                minutes: minutes,
                isBlocking: sessionDomainState.isBlocking
            )
        else { return }
        applyPauseEngineState(transition.state)
        if transition.shouldStartTimer {
            let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 1) { [weak self] in
                guard let self = self else { return }
                let result = self.logicFacade.pauseTick(
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
        let transition = logicFacade.cancelPause(state: sessionDomainState.pauseEngineState)
        applyPauseEngineState(transition.state)
        if transition.shouldStopTimer {
            timerCoordinator.replacePauseTimer(with: nil)
        }
        if transition.shouldCheckSchedules {
            checkSchedules()
        }
    }
}
