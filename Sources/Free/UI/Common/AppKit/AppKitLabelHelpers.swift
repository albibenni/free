import AppKit

@MainActor
func makeAppKitHeaderRow(
    title: String,
    symbolName: String,
    color: NSColor,
    trailingView: NSView? = nil
) -> NSView {
    let iconView = NSImageView()
    iconView.image = appKitSymbolImage(
        named: symbolName,
        pointSize: 16,
        weight: .semibold,
        color: color
    )
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.widthAnchor.constraint(equalToConstant: 18).isActive = true
    iconView.heightAnchor.constraint(equalToConstant: 18).isActive = true

    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = AppKitUIConstants.Typography.cardTitle
    titleLabel.textColor = .labelColor

    let row = NSStackView()
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = AppKitUIConstants.Spacing.sectionStack
    row.addArrangedSubview(iconView)
    row.addArrangedSubview(titleLabel)
    row.addArrangedSubview(NSView())
    if let trailingView {
        row.addArrangedSubview(trailingView)
    }
    return row
}

@MainActor
func makeAppKitSectionLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = AppKitUIConstants.Typography.helperLabel
    label.textColor = .secondaryLabelColor
    return label
}

@MainActor
func makeAppKitBodyLabel(_ text: String, alignment: NSTextAlignment = .left) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = AppKitUIConstants.Typography.body
    label.textColor = .secondaryLabelColor
    label.alignment = alignment
    label.lineBreakMode = .byTruncatingTail
    return label
}
