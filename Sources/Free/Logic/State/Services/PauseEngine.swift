import Foundation

struct PauseEngine {
    struct State: Equatable {
        var isPaused: Bool
        var remaining: TimeInterval
    }

    static func start(
        from state: State,
        minutes: Double,
        isBlocking: Bool
    ) -> State {
        guard isBlocking, minutes > 0 else { return state }
        return State(isPaused: true, remaining: minutes * 60)
    }

    static func tick(from state: State) -> State {
        guard state.isPaused else { return state }
        if state.remaining > 0 {
            return State(isPaused: true, remaining: state.remaining - 1)
        }
        return State(isPaused: false, remaining: state.remaining)
    }

    static func cancel(from state: State) -> State {
        State(isPaused: false, remaining: state.remaining)
    }
}
