import AppKit
import Foundation

enum AllowedWebsitesRuleSetListBuilder {
    static func rebuild(
        in stack: NSStackView,
        rows: [AllowedWebsitesPresentationCoordinator.RuleSetRow],
        accentColor: NSColor,
        isRowSelectionEnabled: Bool,
        onSelect: @escaping (UUID) -> Void
    ) -> [UUID: AppKitSelectableRowButton] {
        clearArrangedSubviews(from: stack)
        var buttons: [UUID: AppKitSelectableRowButton] = [:]

        for row in rows {
            let button = makeAppKitSelectableRowButton(
                title: row.title,
                isSelected: row.isSelected,
                accentColor: accentColor
            ) {
                onSelect(row.id)
            }
            button.isEnabled = isRowSelectionEnabled
            stack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            buttons[row.id] = button
        }

        return buttons
    }

    private static func clearArrangedSubviews(from stack: NSStackView) {
        for subview in stack.arrangedSubviews {
            stack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }
}
