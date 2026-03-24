import Foundation

extension AppState {
    var isPomodoroLocked: Bool {
        PomodoroEngine.isLocked(
            isStrict: isStrict,
            status: pomodoroStatus,
            startedAt: pomodoroStartedAt
        )
    }

    var isPomodoroWithinStrictGracePeriod: Bool {
        guard isStrict, pomodoroStatus != .none, let startedAt = pomodoroStartedAt else {
            return false
        }
        return !PomodoroEngine.isLocked(
            isStrict: isStrict,
            status: pomodoroStatus,
            startedAt: startedAt
        )
    }

    var isStrictActive: Bool { isBlocking && isStrict }

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
