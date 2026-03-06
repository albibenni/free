import Foundation

extension AppState {
    func stopPomodoroWithChallenge(phrase: String) -> Bool {
        let result = logicFacade.stopPomodoroChallenge(
            phrase: phrase,
            challengePhrase: AppState.challengePhrase,
            currentIsUnblockable: isUnblockable
        )
        guard result.didSucceed else { return false }

        isUnblockable = result.temporaryIsUnblockable
        stopPomodoro()
        isUnblockable = result.restoredIsUnblockable
        return true
    }

    func disableUnblockableWithChallenge(phrase: String) -> Bool {
        let result = logicFacade.disableUnblockableChallenge(
            phrase: phrase,
            challengePhrase: AppState.challengePhrase,
            currentIsUnblockable: isUnblockable
        )
        guard result.didSucceed else { return false }
        isUnblockable = result.isUnblockable
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
