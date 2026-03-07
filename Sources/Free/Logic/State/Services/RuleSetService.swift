import Foundation

struct RuleSetService {
    static func normalizeRuleSetId(_ id: UUID?, in ruleSets: [RuleSet]) -> UUID? {
        if let id, ruleSets.contains(where: { $0.id == id }) {
            return id
        }
        return ruleSets.first?.id
    }

    static func ruleSet(for id: UUID?, in ruleSets: [RuleSet]) -> RuleSet? {
        guard let normalizedId = normalizeRuleSetId(id, in: ruleSets) else { return nil }
        return ruleSets.first(where: { $0.id == normalizedId })
    }

    static func activeScheduleRuleSetIds(from schedules: [Schedule]) -> [UUID] {
        var orderedIds: [UUID] = []
        for schedule in schedules {
            guard schedule.isActive(), schedule.type == .focus else { continue }
            guard let ruleSetId = schedule.ruleSetId,
                  !orderedIds.contains(ruleSetId)
            else { continue }
            orderedIds.append(ruleSetId)
        }
        return orderedIds
    }

    static func currentPrimaryRuleSetId(
        ruleSets: [RuleSet],
        schedules: [Schedule],
        activeRuleSetId: UUID?,
        pomodoroRuleSetId: UUID?,
        isPomodoroFocus: Bool,
        isBlocking: Bool,
        wasStartedBySchedule: Bool
    ) -> UUID? {
        if isPomodoroFocus {
            return normalizeRuleSetId(pomodoroRuleSetId ?? activeRuleSetId, in: ruleSets)
        }
        if isBlocking && !wasStartedBySchedule {
            return normalizeRuleSetId(activeRuleSetId, in: ruleSets)
        }
        let activeIds = activeScheduleRuleSetIds(from: schedules)
        if activeIds.count == 1 {
            return activeIds[0]
        }
        if activeIds.count > 1 {
            return nil
        }
        return ruleSets.first?.id
    }

    static func currentPrimaryRuleSetName(
        ruleSets: [RuleSet],
        schedules: [Schedule],
        currentPrimaryRuleSetId: UUID?,
        isPomodoroFocus: Bool,
        isBlocking: Bool,
        wasStartedBySchedule: Bool
    ) -> String {
        if !isPomodoroFocus && (!isBlocking || wasStartedBySchedule) {
            let activeIds = activeScheduleRuleSetIds(from: schedules)
            if activeIds.count > 1 {
                return "Multiple Lists"
            }
        }
        guard let id = currentPrimaryRuleSetId else { return "No List" }
        return ruleSets.first { $0.id == id }?.name ?? "Unknown List"
    }

    static func allowedRules(
        ruleSets: [RuleSet],
        schedules: [Schedule],
        activeRuleSetId: UUID?,
        pomodoroRuleSetId: UUID?,
        isPomodoroFocus: Bool,
        isBlocking: Bool,
        wasStartedBySchedule: Bool
    ) -> [String] {
        if isPomodoroFocus {
            return ruleSet(for: pomodoroRuleSetId ?? activeRuleSetId, in: ruleSets)?.urls ?? []
        }

        var urls = Set<String>()
        schedules.filter { $0.isActive() && $0.type == .focus }.forEach { schedule in
            if let id = schedule.ruleSetId,
               let set = ruleSets.first(where: { $0.id == id })
            {
                urls.formUnion(set.urls)
            }
        }

        if isBlocking && !wasStartedBySchedule,
           let set = ruleSet(for: activeRuleSetId, in: ruleSets)
        {
            urls.formUnion(set.urls)
        }

        if urls.isEmpty && isBlocking, let firstSet = ruleSets.first {
            urls.formUnion(firstSet.urls)
        }

        return Array(urls)
    }

    static func addRule(_ rule: String, to setId: UUID, in ruleSets: inout [RuleSet]) {
        updateSet(setId, in: &ruleSets) { set in
            let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !set.urls.contains(trimmed) {
                set.urls.append(trimmed)
            }
        }
    }

    static func addSpecificRule(_ rule: String, to setId: UUID, in ruleSets: inout [RuleSet]) {
        updateSet(setId, in: &ruleSets) { set in
            if !set.urls.contains(rule) {
                set.urls.append(rule)
            }
        }
    }

    static func removeRule(_ rule: String, from setId: UUID, in ruleSets: inout [RuleSet]) {
        updateSet(setId, in: &ruleSets) { set in
            set.urls.removeAll { $0 == rule }
        }
    }

    static func deleteSet(
        id: UUID,
        in ruleSets: inout [RuleSet],
        activeRuleSetId: inout UUID?
    ) {
        ruleSets.removeAll { $0.id == id }
        if activeRuleSetId == id {
            activeRuleSetId = ruleSets.first?.id
        }
    }

    private static func updateSet(
        _ id: UUID,
        in ruleSets: inout [RuleSet],
        action: (inout RuleSet) -> Void
    ) {
        if let index = ruleSets.firstIndex(where: { $0.id == id }) {
            action(&ruleSets[index])
        }
    }
}
