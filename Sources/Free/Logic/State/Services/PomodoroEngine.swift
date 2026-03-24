import Foundation

struct PomodoroEngine {
    struct State: Equatable {
        var status: PomodoroStatus
        var remaining: TimeInterval
        var startedAt: Date?
        var ruleSetId: UUID?
    }

    static func isLocked(
        isStrict: Bool,
        status: PomodoroStatus,
        startedAt: Date?,
        now: Date = Date(),
        gracePeriod: TimeInterval = 10
    ) -> Bool {
        guard isStrict, status != .none, let startedAt else { return false }
        return now.timeIntervalSince(startedAt) > gracePeriod
    }

    static func startFocus(
        from state: State,
        focusDurationMinutes: Double,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        now: Date = Date()
    ) -> State {
        var updated = state
        if updated.status == .none {
            updated.ruleSetId = RuleSetService.normalizeRuleSetId(activeRuleSetId, in: ruleSets)
        }
        updated.ruleSetId = RuleSetService.normalizeRuleSetId(
            updated.ruleSetId ?? activeRuleSetId,
            in: ruleSets
        )
        updated.status = .focus
        updated.remaining = focusDurationMinutes * 60
        updated.startedAt = now
        return updated
    }

    static func startBreak(
        from state: State,
        breakDurationMinutes: Double
    ) -> State {
        var updated = state
        updated.status = .breakTime
        updated.remaining = breakDurationMinutes * 60
        return updated
    }

    static func stop(from state: State) -> State {
        var updated = state
        updated.status = .none
        updated.ruleSetId = nil
        return updated
    }
}
