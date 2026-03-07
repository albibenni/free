import Foundation

enum AppStateActionsMutationService {
    struct ChallengeContext {
        let currentIsUnblockable: Bool
        let challengePhrase: String
    }

    struct StopPomodoroChallengeUpdate {
        let didSucceed: Bool
        let temporaryIsUnblockable: Bool
        let restoredIsUnblockable: Bool
    }

    struct DisableUnblockableChallengeUpdate {
        let didSucceed: Bool
        let isUnblockable: Bool
    }

    static func stopPomodoroWithChallenge(
        logicFacade: AppStateLogicFacade,
        phrase: String,
        context: ChallengeContext
    ) -> StopPomodoroChallengeUpdate {
        let result = logicFacade.stopPomodoroChallenge(
            phrase: phrase,
            challengePhrase: context.challengePhrase,
            currentIsUnblockable: context.currentIsUnblockable
        )
        return StopPomodoroChallengeUpdate(
            didSucceed: result.didSucceed,
            temporaryIsUnblockable: result.temporaryIsUnblockable,
            restoredIsUnblockable: result.restoredIsUnblockable
        )
    }

    static func disableUnblockableWithChallenge(
        logicFacade: AppStateLogicFacade,
        phrase: String,
        context: ChallengeContext
    ) -> DisableUnblockableChallengeUpdate {
        let result = logicFacade.disableUnblockableChallenge(
            phrase: phrase,
            challengePhrase: context.challengePhrase,
            currentIsUnblockable: context.currentIsUnblockable
        )
        return DisableUnblockableChallengeUpdate(
            didSucceed: result.didSucceed,
            isUnblockable: result.isUnblockable
        )
    }

    static func prepareLaunchAtLoginPromptIfNeeded(
        logicFacade: AppStateLogicFacade,
        launchService: LaunchAtLoginService
    ) -> Bool {
        logicFacade.prepareLaunchAtLoginPromptIfNeeded(service: launchService)
    }

    static func launchAtLoginStatus(
        logicFacade: AppStateLogicFacade,
        launchService: LaunchAtLoginService
    ) -> Bool {
        logicFacade.launchAtLoginStatus(service: launchService)
    }

    static func enableLaunchAtLogin(
        logicFacade: AppStateLogicFacade,
        launchService: LaunchAtLoginService
    ) -> Bool {
        logicFacade.enableLaunchAtLogin(service: launchService)
    }

    static func setLaunchAtLoginEnabled(
        logicFacade: AppStateLogicFacade,
        launchService: LaunchAtLoginService,
        enabled: Bool
    ) -> Bool {
        logicFacade.setLaunchAtLoginEnabled(enabled, service: launchService)
    }

    static func formatTimeString(
        logicFacade: AppStateLogicFacade,
        time: TimeInterval
    ) -> String {
        logicFacade.timeString(time: time)
    }
}
