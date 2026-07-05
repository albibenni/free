import Foundation

@MainActor
enum AppStatePomodoroMutationService {
    struct Context {
        let state: PomodoroEngine.State
        let status: PomodoroStatus
        let remaining: TimeInterval
        let focusDurationMinutes: Double
        let breakDurationMinutes: Double
        let activeRuleSetId: UUID?
        let ruleSets: [RuleSet]
        let isLocked: Bool
    }

    static func startPomodoro(
        logicFacade: AppStateLogicFacade,
        context: Context
    ) -> AppStateLogicFacade.PomodoroTransition {
        logicFacade.startPomodoro(
            state: context.state,
            focusDurationMinutes: context.focusDurationMinutes,
            activeRuleSetId: context.activeRuleSetId,
            ruleSets: context.ruleSets
        )
    }

    static func startBreak(
        logicFacade: AppStateLogicFacade,
        context: Context
    ) -> AppStateLogicFacade.PomodoroTransition {
        logicFacade.startBreak(
            state: context.state,
            breakDurationMinutes: context.breakDurationMinutes
        )
    }

    static func stopPomodoroIfUnlocked(
        logicFacade: AppStateLogicFacade,
        context: Context
    ) -> AppStateLogicFacade.PomodoroTransition? {
        logicFacade.stopPomodoroIfUnlocked(
            state: context.state,
            isLocked: context.isLocked
        )
    }

    static func skipPhaseAction(
        logicFacade: AppStateLogicFacade,
        status: PomodoroStatus
    ) -> AppStateLogicFacade.SkipPhaseAction {
        logicFacade.skipPhaseAction(for: status)
    }

    static func tickAction(
        logicFacade: AppStateLogicFacade,
        context: Context
    ) -> AppStateLogicFacade.PomodoroTickAction {
        logicFacade.pomodoroTickAction(
            status: context.status,
            remaining: context.remaining
        )
    }
}
