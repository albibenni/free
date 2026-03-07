import AppKit
import Foundation

enum FocusPomodoroWidgetSupport {
    static let sidebarPresets: [(focus: Double, breakTime: Double, label: String)] = [
        (25, 5, "25/5"),
        (45, 15, "45/15"),
        (50, 10, "50/10"),
        (90, 20, "90/20"),
    ]

    static func selectedRuleSetId(_ appState: AppState) -> UUID? {
        appState.activeRuleSetId ?? appState.ruleSets.first?.id
    }

    static func firstLabel(in view: NSView) -> NSTextField? {
        if let label = view as? NSTextField {
            return label
        }
        for subview in view.subviews {
            if let label = firstLabel(in: subview) {
                return label
            }
        }
        return nil
    }
}
