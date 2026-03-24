import Foundation

extension AppStateLogicFacade {
    func stopPomodoroChallenge(
        phrase: String,
        challengePhrase: String,
        currentIsStrict: Bool
    ) -> ChallengeStopResult {
        AppStateChallengeCoordinator.stopPomodoro(
            phrase: phrase,
            challengePhrase: challengePhrase,
            currentIsStrict: currentIsStrict
        )
    }

    func disableStrictChallenge(
        phrase: String,
        challengePhrase: String,
        currentIsStrict: Bool
    ) -> ChallengeDisableResult {
        AppStateChallengeCoordinator.disableStrict(
            phrase: phrase,
            challengePhrase: challengePhrase,
            currentIsStrict: currentIsStrict
        )
    }

    func startPomodoro(
        state: PomodoroEngine.State,
        focusDurationMinutes: Double,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet]
    ) -> PomodoroTransition {
        AppStateFocusFlowCoordinator.startPomodoro(
            state: state,
            focusDurationMinutes: focusDurationMinutes,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets
        )
    }

    func stopPomodoroIfUnlocked(
        state: PomodoroEngine.State,
        isLocked: Bool
    ) -> PomodoroTransition? {
        AppStateFocusFlowCoordinator.stopPomodoroIfUnlocked(
            state: state,
            isLocked: isLocked
        )
    }

    func skipPhaseAction(for status: PomodoroStatus) -> SkipPhaseAction {
        AppStateFocusFlowCoordinator.skipPhaseAction(for: status)
    }

    func startBreak(
        state: PomodoroEngine.State,
        breakDurationMinutes: Double
    ) -> PomodoroTransition {
        AppStateFocusFlowCoordinator.startBreak(
            state: state,
            breakDurationMinutes: breakDurationMinutes
        )
    }

    func startPause(
        state: PauseEngine.State,
        minutes: Double,
        isBlocking: Bool
    ) -> PauseTransition? {
        AppStateFocusFlowCoordinator.startPause(
            state: state,
            minutes: minutes,
            isBlocking: isBlocking
        )
    }

    func pauseTick(state: PauseEngine.State) -> PauseTickTransition {
        AppStateFocusFlowCoordinator.pauseTick(state: state)
    }

    func cancelPause(state: PauseEngine.State) -> PauseTransition {
        AppStateFocusFlowCoordinator.cancelPause(state: state)
    }

    func pomodoroTickAction(
        status: PomodoroStatus,
        remaining: TimeInterval
    ) -> PomodoroTickAction {
        AppStateFocusFlowCoordinator.pomodoroTickAction(status: status, remaining: remaining)
    }

    func timeString(time: TimeInterval) -> String {
        AppStateReadModelCoordinator.timeString(time: time)
    }
}
