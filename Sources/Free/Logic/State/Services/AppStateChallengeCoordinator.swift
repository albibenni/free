import Foundation

enum AppStateChallengeCoordinator {
    struct DisableUnblockableResult: Equatable {
        let didSucceed: Bool
        let isUnblockable: Bool
    }

    struct StopPomodoroResult: Equatable {
        let didSucceed: Bool
        let temporaryIsUnblockable: Bool
        let restoredIsUnblockable: Bool
    }

    static func disableUnblockable(
        phrase: String,
        challengePhrase: String,
        currentIsUnblockable: Bool
    ) -> DisableUnblockableResult {
        guard phrase == challengePhrase else {
            return DisableUnblockableResult(
                didSucceed: false,
                isUnblockable: currentIsUnblockable
            )
        }

        return DisableUnblockableResult(didSucceed: true, isUnblockable: false)
    }

    static func stopPomodoro(
        phrase: String,
        challengePhrase: String,
        currentIsUnblockable: Bool
    ) -> StopPomodoroResult {
        guard phrase == challengePhrase else {
            return StopPomodoroResult(
                didSucceed: false,
                temporaryIsUnblockable: currentIsUnblockable,
                restoredIsUnblockable: currentIsUnblockable
            )
        }

        return StopPomodoroResult(
            didSucceed: true,
            temporaryIsUnblockable: false,
            restoredIsUnblockable: currentIsUnblockable
        )
    }
}
