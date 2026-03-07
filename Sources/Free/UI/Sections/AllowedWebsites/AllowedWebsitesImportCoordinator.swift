import AppKit
import Foundation

enum AllowedWebsitesImportCoordinator {
    struct Candidate {
        let rule: String
        let title: String
        let isSelectable: Bool
        let defaultSelected: Bool
    }

    static func buildCandidates(
        currentOpenUrls: [String],
        selectedSet: RuleSet
    ) -> [Candidate] {
        RulesSectionSupport.importableWebsiteCandidates(
            from: currentOpenUrls,
            existing: selectedSet
        ).map { candidate in
            Candidate(
                rule: candidate.rule,
                title: candidate.isAlreadyAllowed
                    ? "\(candidate.rule) (already allowed)"
                    : candidate.rule,
                isSelectable: !candidate.isAlreadyAllowed,
                defaultSelected: !candidate.isAlreadyAllowed
            )
        }
    }

    static func selectedRulesToImport(
        candidates: [Candidate],
        checkboxStates: [NSControl.StateValue]
    ) -> [String] {
        candidates.enumerated().compactMap { index, candidate in
            guard candidate.isSelectable else { return nil }
            guard index < checkboxStates.count, checkboxStates[index] == .on else { return nil }
            return candidate.rule
        }
    }
}
