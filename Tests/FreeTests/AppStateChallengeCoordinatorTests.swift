import Testing

@testable import FreeLogic

struct AppStateChallengeCoordinatorTests {
    @Test("disableStrict succeeds only with exact challenge phrase")
    func disableStrictRequiresExactPhrase() {
        let failed = AppStateChallengeCoordinator.disableStrict(
            phrase: "wrong",
            challengePhrase: AppState.challengePhrase,
            currentIsStrict: true
        )
        #expect(!failed.didSucceed)
        #expect(failed.isStrict)

        let succeeded = AppStateChallengeCoordinator.disableStrict(
            phrase: AppState.challengePhrase,
            challengePhrase: AppState.challengePhrase,
            currentIsStrict: true
        )
        #expect(succeeded.didSucceed)
        #expect(!succeeded.isStrict)
    }

    @Test("stopPomodoro returns temporary and restored strict states")
    func stopPomodoroStateTransition() {
        let failed = AppStateChallengeCoordinator.stopPomodoro(
            phrase: "wrong",
            challengePhrase: AppState.challengePhrase,
            currentIsStrict: true
        )
        #expect(!failed.didSucceed)
        #expect(failed.temporaryIsStrict)
        #expect(failed.restoredIsStrict)

        let succeeded = AppStateChallengeCoordinator.stopPomodoro(
            phrase: AppState.challengePhrase,
            challengePhrase: AppState.challengePhrase,
            currentIsStrict: true
        )
        #expect(succeeded.didSucceed)
        #expect(!succeeded.temporaryIsStrict)
        #expect(succeeded.restoredIsStrict)
    }
}
