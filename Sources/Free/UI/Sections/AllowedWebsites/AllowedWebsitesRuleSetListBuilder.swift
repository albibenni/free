import AppKit
import Foundation

enum AllowedWebsitesRuleSetListBuilder {
    static func updateOrRebuild(
        in stack: NSStackView,
        rows: [AllowedWebsitesPresentationCoordinator.RuleSetRow],
        accentColor: NSColor,
        isRowSelectionEnabled: Bool,
        existingButtons: [UUID: AppKitSelectableRowButton],
        onSelect: @escaping (UUID) -> Void
    ) -> [UUID: AppKitSelectableRowButton] {
        guard canReuseExistingRows(
            in: stack,
            rows: rows,
            existingButtons: existingButtons
        ) else {
            return rebuild(
                in: stack,
                rows: rows,
                accentColor: accentColor,
                isRowSelectionEnabled: isRowSelectionEnabled,
                onSelect: onSelect
            )
        }

        for row in rows {
            guard let button = existingButtons[row.id] else { continue }
            button.accentColor = accentColor
            button.applySelectionState(row.isSelected)
            button.isEnabled = isRowSelectionEnabled
        }

        return existingButtons
    }

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
            button.identifier = NSUserInterfaceItemIdentifier(row.id.uuidString)
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

    private static func canReuseExistingRows(
        in stack: NSStackView,
        rows: [AllowedWebsitesPresentationCoordinator.RuleSetRow],
        existingButtons: [UUID: AppKitSelectableRowButton]
    ) -> Bool {
        guard rows.count == existingButtons.count else { return false }
        guard rows.allSatisfy({
            guard let button = existingButtons[$0.id] else { return false }
            return button.displayedTitleForTesting == $0.title
        }) else { return false }

        let currentOrder = stack.arrangedSubviews.compactMap {
            UUID(uuidString: $0.identifier?.rawValue ?? "")
        }
        let expectedOrder = rows.map(\.id)
        return currentOrder == expectedOrder
    }
}
