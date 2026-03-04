import AppKit

class AppKitFlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class AppKitToggleSwitch: NSControl {
    private let knobView = NSView()
    private var knobLeadingConstraint: NSLayoutConstraint?

    var accentColor: NSColor = .controlAccentColor {
        didSet { updateAppearance() }
    }

    var state: NSControl.StateValue = .off {
        didSet { updateAppearance() }
    }

    override var isEnabled: Bool {
        didSet { updateAppearance() }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 52, height: 28)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.cornerCurve = .continuous

        knobView.wantsLayer = true
        knobView.layer?.cornerCurve = .continuous
        knobView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.25).cgColor
        knobView.layer?.shadowOpacity = 1
        knobView.layer?.shadowRadius = 2
        knobView.layer?.shadowOffset = CGSize(width: 0, height: -1)
        knobView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(knobView)
        knobLeadingConstraint = knobView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2)

        NSLayoutConstraint.activate([
            knobView.widthAnchor.constraint(equalToConstant: 24),
            knobView.heightAnchor.constraint(equalToConstant: 24),
            knobView.centerYAnchor.constraint(equalTo: centerYAnchor),
            knobLeadingConstraint!,
        ])

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
        knobView.layer?.cornerRadius = knobView.bounds.height / 2
        updateKnobPosition()
    }

    override var acceptsFirstResponder: Bool { isEnabled }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return }
        toggle()
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        if event.charactersIgnoringModifiers == " " {
            toggle()
        } else {
            super.keyDown(with: event)
        }
    }

    private func toggle() {
        state = state == .on ? .off : .on
        _ = sendAction(action, to: target)
    }

    private func updateKnobPosition() {
        let knobWidth = knobView.bounds.width > 0 ? knobView.bounds.width : 24
        knobLeadingConstraint?.constant = state == .on
            ? max(bounds.width - knobWidth - 2, 2)
            : 2
    }

    private func updateAppearance() {
        let resolvedAccent = isEnabled
            ? accentColor
            : accentColor.withAlphaComponent(0.35)
        let offColor = isEnabled
            ? NSColor.tertiaryLabelColor.withAlphaComponent(0.45)
            : NSColor.tertiaryLabelColor.withAlphaComponent(0.22)
        layer?.backgroundColor = (state == .on ? resolvedAccent : offColor).cgColor
        knobView.layer?.backgroundColor = (isEnabled ? NSColor.white : NSColor.white.withAlphaComponent(0.7)).cgColor
        updateKnobPosition()
        needsLayout = true
    }
}

class ActionButton: NSButton {
    var onAction: (() -> Void)?
    private let backgroundGradientLayer = CAGradientLayer()

    init(title: String = "", image: NSImage? = nil) {
        super.init(frame: .zero)
        self.title = title
        self.image = image
        wantsLayer = true
        target = self
        action = #selector(handleAction)

        backgroundGradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        backgroundGradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        backgroundGradientLayer.isHidden = true
        layer?.insertSublayer(backgroundGradientLayer, at: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func handleAction() {
        onAction?()
    }

    override func layout() {
        super.layout()
        backgroundGradientLayer.frame = bounds
        backgroundGradientLayer.cornerRadius = layer?.cornerRadius ?? 0
    }

    func setGradientBackground(
        colors: [NSColor],
        borderColor: NSColor? = nil,
        borderWidth: CGFloat = 1
    ) {
        backgroundGradientLayer.isHidden = false
        backgroundGradientLayer.colors = colors.map(\.cgColor)
        layer?.backgroundColor = nil
        layer?.borderColor = borderColor?.cgColor
        layer?.borderWidth = borderWidth
        needsLayout = true
    }
}

final class LeadingInsetButtonCell: NSButtonCell {
    var leadingInset: CGFloat = 8
    var titleAdditionalInset: CGFloat = 8

    override func imageRect(forBounds rect: NSRect) -> NSRect {
        var imageRect = super.imageRect(forBounds: rect)
        imageRect.origin.x += leadingInset
        return imageRect
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)
        let totalInset = leadingInset + titleAdditionalInset
        titleRect.origin.x += totalInset
        titleRect.size.width = max(titleRect.size.width - totalInset, 0)
        return titleRect
    }
}

final class LeadingInsetActionButton: ActionButton {
    override class var cellClass: AnyClass? {
        get { LeadingInsetButtonCell.self }
        set { }
    }

    var leadingInset: CGFloat {
        get { (cell as? LeadingInsetButtonCell)?.leadingInset ?? 0 }
        set { (cell as? LeadingInsetButtonCell)?.leadingInset = newValue }
    }

    var titleAdditionalInset: CGFloat {
        get { (cell as? LeadingInsetButtonCell)?.titleAdditionalInset ?? 0 }
        set { (cell as? LeadingInsetButtonCell)?.titleAdditionalInset = newValue }
    }
}

class AppKitCardView: AppKitFlippedView {
    let contentStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        layer?.cornerRadius = AppKitUIConstants.CornerRadius.card
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.borderWidth = 1

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = AppKitUIConstants.Spacing.cardStack
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: AppKitUIConstants.Spacing.cardPadding
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -AppKitUIConstants.Spacing.cardPadding
            ),
            contentStack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: AppKitUIConstants.Spacing.cardPadding
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -AppKitUIConstants.Spacing.cardPadding
            ),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

func appKitSymbolImage(
    named symbolName: String,
    pointSize: CGFloat,
    weight: NSFont.Weight,
    color: NSColor? = nil
) -> NSImage? {
    guard let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
        return nil
    }

    var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    if let color {
        configuration = configuration.applying(.init(paletteColors: [color]))
    }
    return baseImage.withSymbolConfiguration(configuration) ?? baseImage
}

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

func resolvedAppKitControlSymbolName(_ symbol: String) -> String {
    switch symbol {
    case "+":
        return "plus.circle.fill"
    case "-":
        return "minus.circle.fill"
    default:
        return symbol
    }
}

private func blendedColor(
    _ color: NSColor,
    with other: NSColor,
    fraction: CGFloat
) -> NSColor {
    color.blended(withFraction: fraction, of: other) ?? color
}

func configureAppKitIconButton(
    _ button: NSButton,
    symbolName: String,
    pointSize: CGFloat = 11,
    weight: NSFont.Weight = .semibold,
    color: NSColor = .secondaryLabelColor,
    backgroundColor: NSColor? = nil,
    cornerRadius: CGFloat = 0
) {
    button.isBordered = false
    button.wantsLayer = true
    button.layer?.cornerRadius = cornerRadius
    button.layer?.backgroundColor = backgroundColor?.cgColor
    button.image = appKitSymbolImage(
        named: symbolName,
        pointSize: pointSize,
        weight: weight,
        color: color
    )
    button.imagePosition = .imageOnly
    button.imageScaling = .scaleProportionallyUpOrDown
    button.contentTintColor = color
}

func makeAppKitPrimaryButton(title: String, color: NSColor) -> ActionButton {
    let button = ActionButton(title: title)
    button.isBordered = false
    button.layer?.cornerRadius = AppKitUIConstants.CornerRadius.control
    button.setGradientBackground(
        colors: [
            color.withAlphaComponent(0.14),
            color.withAlphaComponent(0.08),
        ],
        borderColor: color.withAlphaComponent(0.24)
    )
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: AppKitUIConstants.Typography.buttonLabel,
            .foregroundColor: color,
        ]
    )
    button.contentTintColor = color
    button.heightAnchor.constraint(equalToConstant: 32).isActive = true
    return button
}

func makeAppKitSecondaryButton(title: String, color: NSColor) -> ActionButton {
    let button = ActionButton(title: title)
    button.isBordered = false
    button.layer?.cornerRadius = AppKitUIConstants.CornerRadius.control
    button.setGradientBackground(
        colors: [
            color.withAlphaComponent(0.14),
            color.withAlphaComponent(0.08),
        ],
        borderColor: color.withAlphaComponent(0.28)
    )
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: AppKitUIConstants.Typography.regular,
            .foregroundColor: color,
        ]
    )
    return button
}

func makeAppKitPillButton(
    title: String,
    isSelected: Bool,
    selectedColor: NSColor,
    unselectedTextColor: NSColor = .secondaryLabelColor,
    width: CGFloat? = nil,
    height: CGFloat = 24,
    font: NSFont = .systemFont(ofSize: 11, weight: .bold),
    action: @escaping () -> Void
) -> ActionButton {
    let button = ActionButton(title: title)
    button.isBordered = false
    button.layer?.cornerRadius = 6
    button.setGradientBackground(
        colors: isSelected
            ? [selectedColor.withAlphaComponent(0.20), selectedColor.withAlphaComponent(0.12)]
            : [
                NSColor.labelColor.withAlphaComponent(0.08),
                NSColor.labelColor.withAlphaComponent(0.04),
            ],
        borderColor: nil,
        borderWidth: 0
    )
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: font,
            .foregroundColor: isSelected ? selectedColor : unselectedTextColor,
        ]
    )
    button.onAction = action
    if let width {
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
    }
    button.heightAnchor.constraint(equalToConstant: height).isActive = true
    return button
}

func makeAppKitSymbolControlButton(
    symbol: String,
    isEnabled: Bool,
    pointSize: CGFloat = 24,
    dimension: CGFloat = 24,
    color: NSColor = .secondaryLabelColor,
    action: @escaping () -> Void
) -> ActionButton {
    let button = ActionButton()
    let resolvedColor = isEnabled ? color : color.withAlphaComponent(0.45)
    button.isBordered = false
    button.focusRingType = .none
    button.layer?.backgroundColor = nil
    button.layer?.borderWidth = 0
    button.image = appKitSymbolImage(
        named: resolvedAppKitControlSymbolName(symbol),
        pointSize: pointSize,
        weight: .regular,
        color: resolvedColor
    )
    button.imagePosition = .imageOnly
    button.imageScaling = .scaleProportionallyUpOrDown
    button.contentTintColor = resolvedColor
    button.onAction = action
    button.isEnabled = isEnabled
    button.translatesAutoresizingMaskIntoConstraints = false
    button.widthAnchor.constraint(equalToConstant: dimension).isActive = true
    button.heightAnchor.constraint(equalToConstant: dimension).isActive = true
    return button
}

func makeAppKitSelectableRowButton(
    title: String,
    isSelected: Bool,
    accentColor: NSColor,
    leadingSelectedSymbol: String = "link.circle.fill",
    leadingUnselectedSymbol: String = "link",
    trailingSelectedSymbol: String? = "checkmark",
    height: CGFloat = 34,
    action: @escaping () -> Void
) -> ActionButton {
    let button = LeadingInsetActionButton(title: title)
    button.leadingInset = 8
    button.titleAdditionalInset = 8
    button.isBordered = false
    button.layer?.cornerRadius = 8
    button.imageHugsTitle = false
    button.setGradientBackground(
        colors: isSelected
            ? [accentColor.withAlphaComponent(0.14), accentColor.withAlphaComponent(0.08)]
            : [
                NSColor.labelColor.withAlphaComponent(0.05),
                NSColor.labelColor.withAlphaComponent(0.02),
            ],
        borderColor: nil,
        borderWidth: 0
    )
    button.image = appKitSymbolImage(
        named: isSelected ? leadingSelectedSymbol : leadingUnselectedSymbol,
        pointSize: 13,
        weight: isSelected ? .semibold : .regular,
        color: isSelected ? accentColor : .secondaryLabelColor
    )
    button.imagePosition = .imageLeading
    button.alignment = .left
    button.contentTintColor = isSelected ? accentColor : .secondaryLabelColor
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular),
            .foregroundColor: isSelected ? NSColor.labelColor : NSColor.secondaryLabelColor,
        ]
    )
    button.onAction = action
    button.heightAnchor.constraint(equalToConstant: height).isActive = true

    if let trailingSelectedSymbol {
        let trailingView = NSImageView()
        trailingView.image = appKitSymbolImage(
            named: trailingSelectedSymbol,
            pointSize: 11,
            weight: .bold,
            color: accentColor
        )
        trailingView.isHidden = !isSelected
        trailingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(trailingView)

        NSLayoutConstraint.activate([
            trailingView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
            trailingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
    }

    return button
}

func makeAppKitDividerView(
    color: NSColor = NSColor.separatorColor.withAlphaComponent(0.4)
) -> NSView {
    let divider = NSView()
    divider.wantsLayer = true
    divider.layer?.backgroundColor = color.cgColor
    divider.translatesAutoresizingMaskIntoConstraints = false
    divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
    return divider
}

func makeAppKitSectionLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = AppKitUIConstants.Typography.helperLabel
    label.textColor = .secondaryLabelColor
    return label
}

func makeAppKitBodyLabel(_ text: String, alignment: NSTextAlignment = .left) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = AppKitUIConstants.Typography.body
    label.textColor = .secondaryLabelColor
    label.alignment = alignment
    label.lineBreakMode = .byTruncatingTail
    return label
}
