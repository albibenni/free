import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct AppStatePauseCoordinatorTests {
    @Test("start returns nil when pause cannot start")
    func startReturnsNilWhenNoStateChange() async throws {
        let blockedOff = AppStatePauseCoordinator.start(
            from: PauseEngine.State(isPaused: false, remaining: 0),
            minutes: 5,
            isBlocking: false
        )
        let nonPositive = AppStatePauseCoordinator.start(
            from: PauseEngine.State(isPaused: false, remaining: 0),
            minutes: 0,
            isBlocking: true
        )

        #expect(blockedOff == nil)
        #expect(nonPositive == nil)
    }

    @Test("start, tick, and cancel proxy PauseEngine semantics")
    func startTickCancelSemantics() async throws {
        let started = AppStatePauseCoordinator.start(
            from: PauseEngine.State(isPaused: false, remaining: 0),
            minutes: 2,
            isBlocking: true
        )
        #expect(started != nil)
        #expect(started?.isPaused == true)
        #expect(started?.remaining == 120)

        let ticked = AppStatePauseCoordinator.tick(from: started!)
        #expect(ticked.remaining == 119)
        #expect(ticked.isPaused == true)

        let canceled = AppStatePauseCoordinator.cancel(from: ticked)
        #expect(canceled.isPaused == false)
        #expect(canceled.remaining == ticked.remaining)
    }
}
