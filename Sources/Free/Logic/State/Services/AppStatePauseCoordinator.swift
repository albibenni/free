import Foundation

struct AppStatePauseCoordinator {
    static func start(
        from state: PauseEngine.State,
        minutes: Double,
        isBlocking: Bool
    ) -> PauseEngine.State? {
        let updated = PauseEngine.start(from: state, minutes: minutes, isBlocking: isBlocking)
        return updated == state ? nil : updated
    }

    static func tick(from state: PauseEngine.State) -> PauseEngine.State {
        PauseEngine.tick(from: state)
    }

    static func cancel(from state: PauseEngine.State) -> PauseEngine.State {
        PauseEngine.cancel(from: state)
    }
}
