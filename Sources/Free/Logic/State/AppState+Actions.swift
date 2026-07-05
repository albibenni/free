import Foundation

extension AppState {
    private var challengeContext: AppStateActionsMutationService.ChallengeContext {
        AppStateActionsMutationService.ChallengeContext(
            currentIsStrict: isStrict,
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

        stopPomodoro(bypassingStrictLock: true)
        return true
    }

    func disableStrictWithChallenge(phrase: String) -> Bool {
        let result = AppStateActionsMutationService.disableStrictWithChallenge(
            logicFacade: logicFacade,
            phrase: phrase,
            context: challengeContext
        )
        guard result.didSucceed else { return false }
        isStrict = result.isStrict
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
