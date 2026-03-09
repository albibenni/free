import Foundation

enum RulesSectionSupport {
    struct OpenTabImportCandidate: Equatable {
        let rule: String
        let isAlreadyAllowed: Bool
    }

    private static let excludedInternalSchemes: Set<String> = [
        "about", "arc", "chrome", "brave", "edge", "viva", "vivaldi", "opera", "file",
    ]

    static func shouldShowDeleteSetButton(ruleSetCount: Int, isBlocking: Bool) -> Bool {
        if ruleSetCount <= 1 { return false }
        return isBlocking == false
    }

    static func sidebarToggleIcon(isSidebarVisible: Bool) -> String {
        isSidebarVisible ? AppKitUISymbols.Name.chevronLeft : AppKitUISymbols.Name.chevronRight
    }

    static func filterSuggestions(_ urls: [String], existing: RuleSet) -> [String] {
        urls.filter { !existing.containsRule($0) }
    }

    static func suggestionsEmptyText(currentOpenUrls: [String]) -> String {
        currentOpenUrls.isEmpty ? "No open tabs detected." : "All open tabs are already allowed."
    }

    static func importableWebsiteCandidates(
        from urls: [String],
        existing: RuleSet?
    ) -> [OpenTabImportCandidate] {
        var orderedRules: [String] = []
        var seen: Set<String> = []

        for url in urls {
            guard let website = websiteRule(from: url) else { continue }
            guard !seen.contains(website) else { continue }
            seen.insert(website)
            orderedRules.append(website)
        }

        return orderedRules.map { rule in
            let isAlreadyAllowed: Bool
            if let existing {
                isAlreadyAllowed = isExactRuleAlreadyPresent(rule: rule, existing: existing)
            } else {
                isAlreadyAllowed = false
            }
            return OpenTabImportCandidate(rule: rule, isAlreadyAllowed: isAlreadyAllowed)
        }
    }

    private static func isExactRuleAlreadyPresent(rule: String, existing: RuleSet) -> Bool {
        let candidate = RuleMatcher.normalize(rule)
        guard !candidate.isEmpty else { return false }

        return existing.urls.contains { RuleMatcher.normalize($0) == candidate }
    }

    private static func websiteRule(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed == "localhost:10000" || trimmed.hasPrefix("localhost:10000/") { return nil }
        let hasExplicitSchemeDelimiter = trimmed.contains("://")
        if !hasExplicitSchemeDelimiter {
            let schemeParts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if schemeParts.count == 2 {
                let schemeCandidate = String(schemeParts[0]).lowercased()
                let isSupportedScheme = schemeCandidate == "http" || schemeCandidate == "https"
                if !isSupportedScheme {
                    return nil
                }
            }
        }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        if let components = URLComponents(string: candidate) {
            if let scheme = components.scheme?.lowercased(),
               excludedInternalSchemes.contains(scheme)
            {
                return nil
            }
            if let host = components.host?.lowercased(), !host.isEmpty {
                // Keep full normalized URL rule (including path/query) so imports can
                // represent specific pages, not just domains.
                return RuleMatcher.normalize(candidate)
            }
        }

        let normalized = RuleMatcher.normalize(trimmed)
        return normalized.isEmpty ? nil : normalized
    }

    static func isExactRuleAlreadyPresentForTesting(rule: String, existing: RuleSet) -> Bool {
        isExactRuleAlreadyPresent(rule: rule, existing: existing)
    }
}
