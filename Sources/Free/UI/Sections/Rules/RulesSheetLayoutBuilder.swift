import AppKit
import Foundation

enum RulesSheetLayoutBuilder {
    static func makeSidebarRow(
        ruleSet: RuleSet,
        isSelected: Bool,
        canDelete: Bool,
        onSelect: Selector,
        onDelete: Selector,
        target: AnyObject?
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        row.wantsLayer = true
        row.layer?.cornerRadius = 6
        row.layer?.backgroundColor =
            isSelected
            ? NSColor.labelColor.withAlphaComponent(0.08).cgColor
            : NSColor.clear.cgColor

        let button = NSButton(title: ruleSet.name, target: target, action: onSelect)
        button.identifier = NSUserInterfaceItemIdentifier(ruleSet.id.uuidString)
        button.isBordered = false
        button.alignment = .left
        button.font = .systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular)
        button.contentTintColor = isSelected ? .labelColor : .secondaryLabelColor
        row.addArrangedSubview(button)
        row.addArrangedSubview(NSView())

        if canDelete {
            let deleteButton = NSButton()
            deleteButton.isBordered = false
            deleteButton.identifier = NSUserInterfaceItemIdentifier(ruleSet.id.uuidString)
            deleteButton.image = appKitSymbolImage(
                named: AppKitUISymbols.Name.minus,
                pointSize: 15,
                weight: .regular,
                color: .systemRed
            )
            deleteButton.contentTintColor = .systemRed
            deleteButton.target = target
            deleteButton.action = onDelete
            row.addArrangedSubview(deleteButton)
        }

        return row
    }

    static func makeRuleRow(
        rule: String,
        onDelete: Selector,
        target: AnyObject?
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        let label = NSTextField(labelWithString: rule)
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        let deleteButton = NSButton()
        deleteButton.isBordered = false
        deleteButton.identifier = NSUserInterfaceItemIdentifier(rule)
        deleteButton.image = appKitSymbolImage(
            spec: AppKitUISymbols.deleteRule,
            color: .systemRed
        )
        deleteButton.contentTintColor = .systemRed
        deleteButton.target = target
        deleteButton.action = onDelete
        row.addArrangedSubview(label)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(deleteButton)
        return row
    }

    static func makeSuggestionRow(
        suggestion: String,
        accentColor: NSColor,
        onAdd: Selector,
        target: AnyObject?
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        let icon = NSImageView(
            image: NSImage(
                systemSymbolName: AppKitUISymbols.Name.plusCircle,
                accessibilityDescription: nil
            ) ?? NSImage()
        )
        icon.contentTintColor = .systemGreen
        let label = NSTextField(labelWithString: suggestion)
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        let addButton = makeAppKitSecondaryButton(title: "Add", color: accentColor)
        addButton.identifier = NSUserInterfaceItemIdentifier(suggestion)
        addButton.target = target
        addButton.action = onAdd
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        addButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(addButton)
        return row
    }
}
