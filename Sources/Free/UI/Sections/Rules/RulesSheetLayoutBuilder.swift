import AppKit
import Foundation

final class RulesSheetSidebarRowView: NSStackView {
    private let selectButton = NSButton(title: "", target: nil, action: nil)
    private let spacer = NSView()
    private var deleteButton: NSButton?
    private(set) var ruleSetId: UUID

    init(ruleSetId: UUID) {
        self.ruleSetId = ruleSetId
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = 8
        edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        wantsLayer = true
        layer?.cornerRadius = 6

        selectButton.isBordered = false
        selectButton.alignment = .left
        addArrangedSubview(selectButton)
        addArrangedSubview(spacer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        title: String,
        ruleSetId: UUID,
        isSelected: Bool,
        canDelete: Bool,
        onSelect: Selector,
        onDelete: Selector,
        target: AnyObject?
    ) {
        self.ruleSetId = ruleSetId
        layer?.backgroundColor =
            isSelected
            ? NSColor.labelColor.withAlphaComponent(0.08).cgColor
            : NSColor.clear.cgColor

        selectButton.title = title
        selectButton.identifier = NSUserInterfaceItemIdentifier(ruleSetId.uuidString)
        selectButton.font = .systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular)
        selectButton.contentTintColor = isSelected ? .labelColor : .secondaryLabelColor
        selectButton.target = target
        selectButton.action = onSelect

        if canDelete {
            let button: NSButton
            if let existingDeleteButton = deleteButton {
                button = existingDeleteButton
            } else {
                button = NSButton()
                addArrangedSubview(button)
                deleteButton = button
            }
            button.identifier = NSUserInterfaceItemIdentifier(ruleSetId.uuidString)
            configureAppKitDangerSymbolButton(button, symbol: AppKitUISymbols.deleteList)
            button.target = target
            button.action = onDelete
        } else if let existingDeleteButton = deleteButton {
            removeArrangedSubview(existingDeleteButton)
            existingDeleteButton.removeFromSuperview()
            deleteButton = nil
        }
    }
}

final class RulesSheetRuleRowView: NSStackView {
    private let label = NSTextField(labelWithString: "")
    private let spacer = NSView()
    private let deleteButton = NSButton()
    private(set) var rule: String

    init(rule: String) {
        self.rule = rule
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = 8

        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        addArrangedSubview(label)
        addArrangedSubview(spacer)

        deleteButton.isBordered = false
        addArrangedSubview(deleteButton)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        rule: String,
        onDelete: Selector,
        target: AnyObject?
    ) {
        self.rule = rule
        label.stringValue = rule
        deleteButton.identifier = NSUserInterfaceItemIdentifier(rule)
        configureAppKitDangerSymbolButton(deleteButton, symbol: AppKitUISymbols.deleteRule)
        deleteButton.target = target
        deleteButton.action = onDelete
    }
}

final class RulesSheetSuggestionRowView: NSStackView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let spacer = NSView()
    private let addButton = ActionButton(title: "Add")
    private(set) var suggestion: String

    init(suggestion: String) {
        self.suggestion = suggestion
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = 8

        icon.image = NSImage(
            systemSymbolName: AppKitUISymbols.Name.plusCircle,
            accessibilityDescription: nil
        )
        icon.contentTintColor = .systemGreen
        addArrangedSubview(icon)

        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        addArrangedSubview(label)
        addArrangedSubview(spacer)

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        addButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        addArrangedSubview(addButton)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        suggestion: String,
        accentColor: NSColor,
        onAdd: Selector,
        target: AnyObject?
    ) {
        self.suggestion = suggestion
        label.stringValue = suggestion
        applyAppKitSecondaryButtonStyle(addButton, title: "Add", color: accentColor)
        addButton.identifier = NSUserInterfaceItemIdentifier(suggestion)
        addButton.target = target
        addButton.action = onAdd
    }
}

enum RulesSheetLayoutBuilder {
    static func makeSidebarRow(
        ruleSet: RuleSet,
        isSelected: Bool,
        canDelete: Bool,
        onSelect: Selector,
        onDelete: Selector,
        target: AnyObject?
    ) -> RulesSheetSidebarRowView {
        let row = RulesSheetSidebarRowView(ruleSetId: ruleSet.id)
        row.configure(
            title: ruleSet.name,
            ruleSetId: ruleSet.id,
            isSelected: isSelected,
            canDelete: canDelete,
            onSelect: onSelect,
            onDelete: onDelete,
            target: target
        )
        return row
    }

    static func makeRuleRow(
        rule: String,
        onDelete: Selector,
        target: AnyObject?
    ) -> RulesSheetRuleRowView {
        let row = RulesSheetRuleRowView(rule: rule)
        row.configure(rule: rule, onDelete: onDelete, target: target)
        return row
    }

    static func makeSuggestionRow(
        suggestion: String,
        accentColor: NSColor,
        onAdd: Selector,
        target: AnyObject?
    ) -> RulesSheetSuggestionRowView {
        let row = RulesSheetSuggestionRowView(suggestion: suggestion)
        row.configure(
            suggestion: suggestion,
            accentColor: accentColor,
            onAdd: onAdd,
            target: target
        )
        return row
    }

    static func updateOrRebuildRuleRows(
        in stack: NSStackView,
        rules: [String],
        existingRows: [String: RulesSheetRuleRowView],
        onDelete: Selector,
        target: AnyObject?
    ) -> [String: RulesSheetRuleRowView] {
        let desired = Set(rules)
        for (rule, row) in existingRows where !desired.contains(rule) {
            stack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        var nextRows: [String: RulesSheetRuleRowView] = [:]
        for rule in rules {
            let row = existingRows[rule] ?? makeRuleRow(
                rule: rule,
                onDelete: onDelete,
                target: target
            )
            row.configure(rule: rule, onDelete: onDelete, target: target)
            nextRows[rule] = row
        }

        for (index, rule) in rules.enumerated() {
            let row = nextRows[rule]!
            if row.superview !== stack {
                stack.insertArrangedSubview(row, at: index)
                continue
            }
            let currentAtIndex = index < stack.arrangedSubviews.count ? stack.arrangedSubviews[index] : nil
            if currentAtIndex === row { continue }
            if stack.arrangedSubviews.contains(where: { $0 === row }) {
                stack.removeArrangedSubview(row)
                row.removeFromSuperview()
            }
            stack.insertArrangedSubview(row, at: index)
        }

        while stack.arrangedSubviews.count > rules.count {
            let last = stack.arrangedSubviews.last!
            stack.removeArrangedSubview(last)
            last.removeFromSuperview()
        }

        return nextRows
    }

    static func updateOrRebuildSuggestionRows(
        in stack: NSStackView,
        suggestions: [String],
        accentColor: NSColor,
        existingRows: [String: RulesSheetSuggestionRowView],
        onAdd: Selector,
        target: AnyObject?
    ) -> [String: RulesSheetSuggestionRowView] {
        let desired = Set(suggestions)
        for (suggestion, row) in existingRows where !desired.contains(suggestion) {
            stack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        var nextRows: [String: RulesSheetSuggestionRowView] = [:]
        for suggestion in suggestions {
            let row = existingRows[suggestion] ?? makeSuggestionRow(
                suggestion: suggestion,
                accentColor: accentColor,
                onAdd: onAdd,
                target: target
            )
            row.configure(
                suggestion: suggestion,
                accentColor: accentColor,
                onAdd: onAdd,
                target: target
            )
            nextRows[suggestion] = row
        }

        for (index, suggestion) in suggestions.enumerated() {
            let row = nextRows[suggestion]!
            if row.superview !== stack {
                stack.insertArrangedSubview(row, at: index)
                continue
            }
            let currentAtIndex = index < stack.arrangedSubviews.count ? stack.arrangedSubviews[index] : nil
            if currentAtIndex === row { continue }
            if stack.arrangedSubviews.contains(where: { $0 === row }) {
                stack.removeArrangedSubview(row)
                row.removeFromSuperview()
            }
            stack.insertArrangedSubview(row, at: index)
        }

        while stack.arrangedSubviews.count > suggestions.count {
            let last = stack.arrangedSubviews.last!
            stack.removeArrangedSubview(last)
            last.removeFromSuperview()
        }

        return nextRows
    }
}
