import AppKit
import Foundation

@MainActor
enum ScheduleEditorLayoutBuilder {
    static func makeImportedBadge() -> NSView {
        let badge = AppKitCardView()
        badge.backgroundColorProvider = { NSColor.secondaryLabelColor.withAlphaComponent(0.12) }
        badge.layer?.borderWidth = 0

        let icon = NSImageView()
        icon.image = appKitSymbolImage(
            spec: AppKitUISymbols.importedEditorBadge,
            color: .secondaryLabelColor
        )

        let label = NSTextField(labelWithString: "Imported from Calendar")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor

        let row = NSStackView(views: [icon, label, NSView()])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        badge.contentStack.addArrangedSubview(row)
        return badge
    }

    static func makeTextFieldSection(
        title: String,
        text: String,
        editable: Bool,
        placeholder: String,
        delegate: NSTextFieldDelegate?
    ) -> NSView {
        let section = EditorSectionView(title: title)
        let field = VerticallyCenteredTextField(string: text)
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: 13, weight: .regular)
        applyAppKitInputFieldStyle(field, backgroundOpacity: 0.66, borderOpacity: 0.8)
        field.heightAnchor.constraint(equalToConstant: 30).isActive = true
        field.delegate = delegate
        field.isEditable = editable
        field.isEnabled = editable
        field.identifier = NSUserInterfaceItemIdentifier("scheduleNameField")
        section.contentStack.addArrangedSubview(field)
        field.widthAnchor.constraint(equalTo: section.contentStack.widthAnchor).isActive = true
        return section
    }

    static func makeThemeColorSection(
        selectedColorIndex: Int,
        onSelect: @escaping (Int) -> Void
    ) -> NSView {
        let section = EditorSectionView(title: "THEME COLOR")
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        for index in 0..<FocusColor.all.count {
            let button = ActionButton()
            button.wantsLayer = true
            button.isBordered = false
            button.layer?.backgroundColor = FocusColor.nsColor(for: index).cgColor
            button.layer?.cornerRadius = 15
            button.layer?.borderWidth = selectedColorIndex == index ? 2 : 0
            button.layer?.borderColor = NSColor.labelColor.cgColor
            button.onAction = { onSelect(index) }
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            row.addArrangedSubview(button)
        }

        section.contentStack.addArrangedSubview(row)
        return section
    }

    static func makeRepeatSection(
        isRecurring: Bool,
        target: AnyObject?,
        action: Selector
    ) -> (container: NSView, checkbox: NSButton) {
        let section = AppKitFlippedView()
        let checkbox = NSButton(checkboxWithTitle: "Repeat weekly", target: target, action: action)
        checkbox.font = .systemFont(ofSize: 14, weight: .semibold)
        checkbox.state = isRecurring ? .on : .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(checkbox)
        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            checkbox.topAnchor.constraint(equalTo: section.topAnchor),
            checkbox.bottomAnchor.constraint(equalTo: section.bottomAnchor),
        ])
        return (section, checkbox)
    }

    static func makeTimePickerCard(
        title: String,
        date: Date,
        target: AnyObject?,
        action: Selector
    ) -> NSView {
        let card = AppKitCardView()
        card.backgroundColorProvider = { NSColor.labelColor.withAlphaComponent(0.03) }

        let label = makeAppKitSectionLabel(title)
        let picker = NSDatePicker()
        picker.datePickerElements = .hourMinute
        picker.datePickerStyle = .textField
        picker.dateValue = date
        picker.target = target
        picker.action = action

        card.contentStack.addArrangedSubview(label)
        card.contentStack.addArrangedSubview(picker)
        return card
    }

    static func makeRecurringDayButton(
        symbol: String,
        onTap: @escaping () -> Void
    ) -> ActionButton {
        let button = ActionButton(title: symbol)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 22
        button.onAction = onTap
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }
}
