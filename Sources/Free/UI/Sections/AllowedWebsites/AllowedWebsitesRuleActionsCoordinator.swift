import Foundation

enum AllowedWebsitesRuleActionsCoordinator {
    static func normalizedRuleInput(_ rawValue: String) -> String? {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

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
