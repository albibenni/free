import Foundation

extension AppState {
    var isPomodoroLocked: Bool {
        PomodoroEngine.isLocked(
            isUnblockable: isUnblockable,
            status: pomodoroStatus,
            startedAt: pomodoroStartedAt
        )
    }

    var isStrictActive: Bool { isBlocking && isUnblockable }

    var currentPrimaryRuleSetId: UUID? {
        logicFacade.currentPrimaryRuleSetId(context: ruleContext)
    }

    var currentPrimaryRuleSetName: String {
        logicFacade.currentPrimaryRuleSetName(context: ruleContext)
    }

    var allowedRules: [String] {
        logicFacade.allowedRules(context: ruleContext)
    }

    var todaySchedules: [Schedule] {
        logicFacade.todaySchedules(from: scheduleDomainState.schedules)
    }
}
