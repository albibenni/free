import Foundation

struct RuleSetCoordinator {
    static func createRuleSet(
        name: String,
        makeActive: Bool,
        in ruleSets: inout [RuleSet],
        activeRuleSetId: inout UUID?
    ) -> RuleSet {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSet = RuleSet(name: trimmed.isEmpty ? "New List" : trimmed, urls: [])
        ruleSets.append(newSet)
        if makeActive {
            activeRuleSetId = newSet.id
        }
        return newSet
    }

    static func selectActiveRuleSet(
        _ id: UUID,
        in ruleSets: [RuleSet],
        currentActiveRuleSetId: UUID?,
        isStrictActive: Bool
    ) -> UUID? {
        guard !isStrictActive else { return currentActiveRuleSetId }
        guard ruleSets.contains(where: { $0.id == id }) else { return currentActiveRuleSetId }
        return id
    }

    @discardableResult
    static func deleteRuleSet(
        id: UUID,
        in ruleSets: inout [RuleSet],
        activeRuleSetId: inout UUID?,
        isStrictActive: Bool
    ) -> Bool {
        guard !isStrictActive else { return false }
        let before = ruleSets.count
        RuleSetService.deleteSet(id: id, in: &ruleSets, activeRuleSetId: &activeRuleSetId)
        return ruleSets.count < before
    }
}
