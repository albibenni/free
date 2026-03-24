import Foundation

enum AppStateActionsMutationService {
    struct ChallengeContext {
        let currentIsStrict: Bool
        let challengePhrase: String
    }

    struct StopPomodoroChallengeUpdate {
        let didSucceed: Bool
        let temporaryIsStrict: Bool
        let restoredIsStrict: Bool
    }

    struct DisableStrictChallengeUpdate {
        let didSucceed: Bool
        let isStrict: Bool
    }

    static func stopPomodoroWithChallenge(
        logicFacade: AppStateLogicFacade,
        phrase: String,
        context: ChallengeContext
    ) -> StopPomodoroChallengeUpdate {
        let result = logicFacade.stopPomodoroChallenge(
            phrase: phrase,
            challengePhrase: context.challengePhrase,
            currentIsStrict: context.currentIsStrict
        )
        return StopPomodoroChallengeUpdate(
            didSucceed: result.didSucceed,
            temporaryIsStrict: result.temporaryIsStrict,
            restoredIsStrict: result.restoredIsStrict
        )
    }

    static func disableStrictWithChallenge(
        logicFacade: AppStateLogicFacade,
        phrase: String,
        context: ChallengeContext
    ) -> DisableStrictChallengeUpdate {
        let result = logicFacade.disableStrictChallenge(
            phrase: phrase,
            challengePhrase: context.challengePhrase,
            currentIsStrict: context.currentIsStrict
        )
        return DisableStrictChallengeUpdate(
            didSucceed: result.didSucceed,
            isStrict: result.isStrict
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
