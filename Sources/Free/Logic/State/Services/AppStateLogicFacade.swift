import Foundation

struct AppStateLogicFacade {
    typealias SessionState = AppStateSessionCoordinator.SessionState
    typealias RuleContext = AppStateReadModelCoordinator.RuleContext
    typealias RuleMutation = AppStateRuleSetCoordinator.RuleMutation
    typealias ScheduleDeleteResult = AppStateScheduleMutationCoordinator.DeletionResult
    typealias ChallengeStopResult = AppStateChallengeCoordinator.StopPomodoroResult
    typealias ChallengeDisableResult = AppStateChallengeCoordinator.DisableUnblockableResult
    typealias PomodoroTransition = AppStateFocusFlowCoordinator.PomodoroTransition
    typealias SkipPhaseAction = AppStateFocusFlowCoordinator.SkipPhaseAction
    typealias PauseTransition = AppStateFocusFlowCoordinator.PauseTransition
    typealias PauseTickTransition = AppStateFocusFlowCoordinator.PauseTickTransition
    typealias PomodoroTickAction = AppStateFocusFlowCoordinator.PomodoroTickAction

    static let live = AppStateLogicFacade()
}
