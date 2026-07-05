import Foundation

extension AppState {
    func stopPomodoroWithChallenge(phrase: String) -> Bool {
        let result = logicFacade.stopPomodoroChallenge(
            phrase: phrase,
            challengePhrase: AppState.challengePhrase,
            currentIsStrict: isStrict
        )
        guard result.didSucceed else { return false }

        stopPomodoro(bypassingStrictLock: true)
        return true
    }

    func disableStrictWithChallenge(phrase: String) -> Bool {
        let result = logicFacade.disableStrictChallenge(
            phrase: phrase,
            challengePhrase: AppState.challengePhrase,
            currentIsStrict: isStrict
        )
        guard result.didSucceed else { return false }
        isStrict = result.isStrict
        return result.didSucceed
    }

    func prepareLaunchAtLoginPromptIfNeeded() -> Bool {
        logicFacade.prepareLaunchAtLoginPromptIfNeeded(service: launchAtLoginService)
    }

    func launchAtLoginStatus() -> Bool {
        logicFacade.launchAtLoginStatus(service: launchAtLoginService)
    }

    @discardableResult
    func enableLaunchAtLogin() -> Bool {
        logicFacade.enableLaunchAtLogin(service: launchAtLoginService)
    }

    @discardableResult
    func setLaunchAtLoginEnabled(_ enabled: Bool) -> Bool {
        logicFacade.setLaunchAtLoginEnabled(enabled, service: launchAtLoginService)
    }

    func timeString(time: TimeInterval) -> String {
        logicFacade.timeString(time: time)
    }
}
