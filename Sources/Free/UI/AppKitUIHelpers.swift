import AppKit

class AppKitFlippedView: NSView {
    override var isFlipped: Bool { true }
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

func makeAppKitSectionLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = AppKitUIConstants.Typography.helperLabel
    label.textColor = .secondaryLabelColor
    return label
}
