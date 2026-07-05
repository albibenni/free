import Foundation

@MainActor
enum AppStatePauseMutationService {
    struct Context {
        let state: PauseEngine.State
        let isBlocking: Bool
    }

    static func startPause(
        logicFacade: AppStateLogicFacade,
        context: Context,
        minutes: Double
    ) -> AppStateLogicFacade.PauseTransition? {
        logicFacade.startPause(
            state: context.state,
            minutes: minutes,
            isBlocking: context.isBlocking
        )
    }

    static func pauseTick(
        logicFacade: AppStateLogicFacade,
        state: PauseEngine.State
    ) -> AppStateLogicFacade.PauseTickTransition {
        logicFacade.pauseTick(state: state)
    }

    static func cancelPause(
        logicFacade: AppStateLogicFacade,
        state: PauseEngine.State
    ) -> AppStateLogicFacade.PauseTransition {
        logicFacade.cancelPause(state: state)
    }
}
