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
        ruleSetCount > 1 && !isBlocking
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
            OpenTabImportCandidate(
                rule: rule,
                isAlreadyAllowed: existing.map { isExactRuleAlreadyPresent(rule: rule, existing: $0) } ?? false
            )
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
        if let colonIndex = trimmed.firstIndex(of: ":"), !trimmed.contains("://") {
            let schemeCandidate = String(trimmed[..<colonIndex]).lowercased()
            if schemeCandidate != "http" && schemeCandidate != "https" {
                return nil
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
}
