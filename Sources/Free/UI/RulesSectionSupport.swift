import Foundation

enum RulesSectionSupport {
    static func shouldShowDeleteSetButton(ruleSetCount: Int, isBlocking: Bool) -> Bool {
        ruleSetCount > 1 && !isBlocking
    }

    static func sidebarToggleIcon(isSidebarVisible: Bool) -> String {
        isSidebarVisible ? "chevron.left" : "chevron.right"
    }

    static func filterSuggestions(_ urls: [String], existing: RuleSet) -> [String] {
        urls.filter { !existing.containsRule($0) }
    }

    static func suggestionsEmptyText(currentOpenUrls: [String]) -> String {
        currentOpenUrls.isEmpty ? "No open tabs detected." : "All open tabs are already allowed."
    }
}
