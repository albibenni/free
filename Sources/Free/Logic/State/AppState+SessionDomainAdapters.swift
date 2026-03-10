import Foundation

extension AppState {
    var sessionState: AppStateLogicFacade.SessionState {
        logicFacade.makeSessionState(
            isBlocking: sessionDomainState.isBlocking,
            wasStartedBySchedule: sessionDomainState.wasStartedBySchedule,
            manuallyPausedScheduleIds: sessionDomainState.manuallyPausedScheduleIds
        )
    }

    func applySessionState(_ state: AppStateLogicFacade.SessionState) {
        manuallyPausedScheduleIds = state.manuallyPausedScheduleIds
        if state.isBlocking != isBlocking {
            isBlocking = state.isBlocking
        }
        if state.wasStartedBySchedule != wasStartedBySchedule {
            setWasStartedBySchedule(state.wasStartedBySchedule)
        }
        if (!state.isBlocking || state.wasStartedBySchedule) && manualBlockingEnabled {
            setManualBlockingEnabled(false)
        }
    }

    var sessionDomainState: AppSessionDomainState {
        AppSessionDomainState(
            isBlocking: isBlocking,
            isUnblockable: isUnblockable,
            isPaused: isPaused,
            pauseRemaining: pauseRemaining,
            wasStartedBySchedule: wasStartedBySchedule,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds
        )
    }

    func applySessionDomainState(_ state: AppSessionDomainState) {
        if isBlocking != state.isBlocking { isBlocking = state.isBlocking }
        if isUnblockable != state.isUnblockable { isUnblockable = state.isUnblockable }
        if isPaused != state.isPaused { isPaused = state.isPaused }
        if pauseRemaining != state.pauseRemaining { pauseRemaining = state.pauseRemaining }
        if wasStartedBySchedule != state.wasStartedBySchedule {
            wasStartedBySchedule = state.wasStartedBySchedule
        }
        if manuallyPausedScheduleIds != state.manuallyPausedScheduleIds {
            manuallyPausedScheduleIds = state.manuallyPausedScheduleIds
        }
    }

    func applyPauseEngineState(_ state: PauseEngine.State) {
        var domainState = sessionDomainState
        domainState.isPaused = state.isPaused
        domainState.pauseRemaining = state.remaining
        applySessionDomainState(domainState)
    }
}
