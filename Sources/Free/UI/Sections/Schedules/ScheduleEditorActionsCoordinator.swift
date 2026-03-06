import AppKit
import Foundation

enum ScheduleEditorActionsCoordinator {
    static func ruleSetIdForSelectedPopupIndex(
        _ index: Int,
        ruleSets: [RuleSet]
    ) -> UUID? {
        guard index > 0 else { return nil }
        return ruleSets[safe: index - 1]?.id
    }

    static func toggledRecurring(
        checkboxState: NSControl.StateValue
    ) -> Bool {
        checkboxState == .on
    }
}
