import Testing

@testable import FreeLogic

struct AppStateChallengeCoordinatorTests {
    @Test("disableUnblockable succeeds only with exact challenge phrase")
    func disableUnblockableRequiresExactPhrase() {
        let failed = AppStateChallengeCoordinator.disableUnblockable(
            phrase: "wrong",
            challengePhrase: AppState.challengePhrase,
            currentIsUnblockable: true
        )
        #expect(!failed.didSucceed)
        #expect(failed.isUnblockable)

        let succeeded = AppStateChallengeCoordinator.disableUnblockable(
            phrase: AppState.challengePhrase,
            challengePhrase: AppState.challengePhrase,
            currentIsUnblockable: true
        )
        #expect(succeeded.didSucceed)
        #expect(!succeeded.isUnblockable)
    }

    @Test("stopPomodoro returns temporary and restored unblockable states")
    func stopPomodoroStateTransition() {
        let failed = AppStateChallengeCoordinator.stopPomodoro(
            phrase: "wrong",
            challengePhrase: AppState.challengePhrase,
            currentIsUnblockable: true
        )
        #expect(!failed.didSucceed)
        #expect(failed.temporaryIsUnblockable)
        #expect(failed.restoredIsUnblockable)

        let succeeded = AppStateChallengeCoordinator.stopPomodoro(
            phrase: AppState.challengePhrase,
            challengePhrase: AppState.challengePhrase,
            currentIsUnblockable: true
        )
        #expect(succeeded.didSucceed)
        #expect(!succeeded.temporaryIsUnblockable)
        #expect(succeeded.restoredIsUnblockable)
    }
}
