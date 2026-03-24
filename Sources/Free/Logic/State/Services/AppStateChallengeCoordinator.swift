import Foundation

enum AppStateChallengeCoordinator {
    struct DisableStrictResult: Equatable {
        let didSucceed: Bool
        let isStrict: Bool
    }

    struct StopPomodoroResult: Equatable {
        let didSucceed: Bool
        let temporaryIsStrict: Bool
        let restoredIsStrict: Bool
    }

    static func disableStrict(
        phrase: String,
        challengePhrase: String,
        currentIsStrict: Bool
    ) -> DisableStrictResult {
        guard phrase == challengePhrase else {
            return DisableStrictResult(
                didSucceed: false,
                isStrict: currentIsStrict
            )
        }

        return DisableStrictResult(didSucceed: true, isStrict: false)
    }

    static func stopPomodoro(
        phrase: String,
        challengePhrase: String,
        currentIsStrict: Bool
    ) -> StopPomodoroResult {
        guard phrase == challengePhrase else {
            return StopPomodoroResult(
                didSucceed: false,
                temporaryIsStrict: currentIsStrict,
                restoredIsStrict: currentIsStrict
            )
        }

        return StopPomodoroResult(
            didSucceed: true,
            temporaryIsStrict: false,
            restoredIsStrict: currentIsStrict
        )
    }
}
