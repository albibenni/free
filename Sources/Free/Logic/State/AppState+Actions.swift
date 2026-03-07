import Foundation

extension AppState {
    private var challengeContext: AppStateActionsMutationService.ChallengeContext {
        AppStateActionsMutationService.ChallengeContext(
            currentIsUnblockable: isUnblockable,
            challengePhrase: AppState.challengePhrase
        )
    }

    func stopPomodoroWithChallenge(phrase: String) -> Bool {
        let result = AppStateActionsMutationService.stopPomodoroWithChallenge(
            logicFacade: logicFacade,
            phrase: phrase,
            context: challengeContext
        )
        guard result.didSucceed else { return false }

        isUnblockable = result.temporaryIsUnblockable
        stopPomodoro()
        isUnblockable = result.restoredIsUnblockable
        return true
    }

    func disableUnblockableWithChallenge(phrase: String) -> Bool {
        let result = AppStateActionsMutationService.disableUnblockableWithChallenge(
            logicFacade: logicFacade,
            phrase: phrase,
            context: challengeContext
        )
        guard result.didSucceed else { return false }
        isUnblockable = result.isUnblockable
        return result.didSucceed
    }

    func prepareLaunchAtLoginPromptIfNeeded() -> Bool {
        AppStateActionsMutationService.prepareLaunchAtLoginPromptIfNeeded(
            logicFacade: logicFacade,
            launchService: launchAtLoginService
        )
    }

    func launchAtLoginStatus() -> Bool {
        AppStateActionsMutationService.launchAtLoginStatus(
            logicFacade: logicFacade,
            launchService: launchAtLoginService
        )
    }

    @discardableResult
    func enableLaunchAtLogin() -> Bool {
        AppStateActionsMutationService.enableLaunchAtLogin(
            logicFacade: logicFacade,
            launchService: launchAtLoginService
        )
    }

    @discardableResult
    func setLaunchAtLoginEnabled(_ enabled: Bool) -> Bool {
        AppStateActionsMutationService.setLaunchAtLoginEnabled(
            logicFacade: logicFacade,
            launchService: launchAtLoginService,
            enabled: enabled
        )
    }

    func timeString(time: TimeInterval) -> String {
        AppStateActionsMutationService.formatTimeString(
            logicFacade: logicFacade,
            time: time
        )
    }
}
