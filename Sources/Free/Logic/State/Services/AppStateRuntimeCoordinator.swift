import Foundation

enum AppStateRuntimeCoordinator {
    struct PauseTickResult: Equatable {
        let state: PauseEngine.State
        let shouldCancel: Bool
    }

    static func pomodoroTickAction(
        status: AppState.PomodoroStatus,
        remaining: TimeInterval
    ) -> AppStatePomodoroCoordinator.TimerAction {
        AppStatePomodoroCoordinator.timerAction(status: status, remaining: remaining)
    }

    static func pauseTick(from state: PauseEngine.State) -> PauseTickResult {
        let ticked = AppStatePauseCoordinator.tick(from: state)
        return PauseTickResult(state: ticked, shouldCancel: !ticked.isPaused)
    }
}
