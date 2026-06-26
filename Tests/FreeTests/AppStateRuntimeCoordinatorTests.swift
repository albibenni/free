import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct AppStateRuntimeCoordinatorTests {
    @Test("pomodoroTickAction mirrors AppStatePomodoroCoordinator timer semantics")
    func pomodoroTickAction() async throws {
        #expect(
            AppStateRuntimeCoordinator.pomodoroTickAction(status: .focus, remaining: 10)
                == .decrement
        )
        #expect(
            AppStateRuntimeCoordinator.pomodoroTickAction(status: .focus, remaining: 0)
                == .startBreak
        )
        #expect(
            AppStateRuntimeCoordinator.pomodoroTickAction(status: .breakTime, remaining: 0)
                == .startFocus
        )
    }

    @Test("pauseTick returns cancellation intent when pause reaches zero")
    func pauseTickCancellationIntent() async throws {
        let active = PauseEngine.State(isPaused: true, remaining: 2)
        let activeResult = AppStateRuntimeCoordinator.pauseTick(from: active)
        #expect(activeResult.state.isPaused)
        #expect(activeResult.state.remaining == 1)
        #expect(!activeResult.shouldCancel)

        let boundary = PauseEngine.State(isPaused: true, remaining: 1)
        let boundaryResult = AppStateRuntimeCoordinator.pauseTick(from: boundary)
        #expect(boundaryResult.state.isPaused)
        #expect(boundaryResult.state.remaining == 0)
        #expect(!boundaryResult.shouldCancel)

        let ending = PauseEngine.State(isPaused: true, remaining: 0)
        let endingResult = AppStateRuntimeCoordinator.pauseTick(from: ending)
        #expect(!endingResult.state.isPaused)
        #expect(endingResult.state.remaining == 0)
        #expect(endingResult.shouldCancel)
    }
}
