import Foundation

enum AllowedWebsitesRuleActionsCoordinator {
    @inline(never)
    static func normalizedRuleInput(_ rawValue: String) -> String? {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    @inline(never)
    @discardableResult
    static func addRule(
        appState: AppState,
        setId: UUID,
        rawValue: String
    ) -> Bool {
        guard let normalized = normalizedRuleInput(rawValue) else { return false }
        appState.addRule(normalized, to: setId)
        return true
    }

    @inline(never)
    @discardableResult
    static func removeRules(
        appState: AppState,
        setId: UUID,
        rules: [String]
    ) -> Int {
        guard !rules.isEmpty else { return 0 }
        for rule in rules {
            appState.removeRule(rule, from: setId)
        }
        return rules.count
    }
}

enum AllowedWebsitesRuleSetActionsCoordinator {
    @inline(never)
    static func canCreateRuleSet(isStrictActive: Bool) -> Bool {
        !isStrictActive
    }

    @inline(never)
    static func canDeleteRuleSet(
        isStrictActive: Bool,
        ruleSetCount: Int
    ) -> Bool {
        !isStrictActive && ruleSetCount > 1
    }

    @inline(never)
    static func selectedRuleSet(
        id: UUID?,
        ruleSets: [RuleSet]
    ) -> RuleSet? {
        guard let id else { return nil }
        return ruleSets.first(where: { $0.id == id })
    }

    @inline(never)
    static func selectedRuleSetAfterRowTap(
        tappedId: UUID,
        currentSelectedId: UUID?,
        isStrictActive: Bool
    ) -> UUID? {
        guard !isStrictActive else { return currentSelectedId }
        return tappedId
    }

    @inline(never)
    static func createRuleSet(
        appState: AppState,
        name: String
    ) -> RuleSet {
        appState.createRuleSet(name: name, makeActive: false)
    }

    @inline(never)
    static func deleteRuleSet(
        appState: AppState,
        id: UUID
    ) {
        appState.deleteSet(id: id)
    }
}
