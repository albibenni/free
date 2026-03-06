import AppKit

final class AppKitSelectableRowButton: ActionButton {
    private let rowTitle: String
    private let leadingSelectedSymbol: String
    private let leadingUnselectedSymbol: String
    private let trailingSelectedSymbol: String?
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let trailingImageView = NSImageView()
    private let contentRow = NSStackView()

    var accentColor: NSColor {
        didSet { applySelectionState(isSelectedState) }
    }

    private(set) var isSelectedState: Bool = false

    init(
        title: String,
        isSelected: Bool,
        accentColor: NSColor,
        leadingSelectedSymbol: String = AppKitUISymbols.Name.linkSelected,
        leadingUnselectedSymbol: String = AppKitUISymbols.Name.link,
        trailingSelectedSymbol: String? = AppKitUISymbols.Name.checkmark
    ) {
        rowTitle = title
        self.accentColor = accentColor
        self.leadingSelectedSymbol = leadingSelectedSymbol
        self.leadingUnselectedSymbol = leadingUnselectedSymbol
        self.trailingSelectedSymbol = trailingSelectedSymbol
        super.init(title: "")

        isBordered = false
        focusRingType = .none
        layer?.cornerRadius = 8
        image = nil
        self.title = ""
        contentTintColor = nil
        (cell as? NSButtonCell)?.highlightsBy = []

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        trailingImageView.translatesAutoresizingMaskIntoConstraints = false
        trailingImageView.imageScaling = .scaleProportionallyUpOrDown
        trailingImageView.widthAnchor.constraint(equalToConstant: 12).isActive = true
        trailingImageView.heightAnchor.constraint(equalToConstant: 12).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        contentRow.orientation = .horizontal
        contentRow.alignment = .centerY
        contentRow.spacing = 8
        contentRow.translatesAutoresizingMaskIntoConstraints = false
        contentRow.addArrangedSubview(iconView)
        contentRow.addArrangedSubview(titleLabel)
        contentRow.addArrangedSubview(spacer)
        contentRow.addArrangedSubview(trailingImageView)
        addSubview(contentRow)

        NSLayoutConstraint.activate([
            contentRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            contentRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentRow.topAnchor.constraint(equalTo: topAnchor),
            contentRow.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        if let trailingSelectedSymbol {
            trailingImageView.image = appKitSymbolImage(
                named: trailingSelectedSymbol,
                pointSize: 11,
                weight: .bold,
                color: accentColor
            )
        }

        applySelectionState(isSelected)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applySelectionState(isSelectedState)
    }

    func applySelectionState(_ isSelected: Bool) {
        isSelectedState = isSelected
        setGradientBackground(
            colors: isSelected
                ? [accentColor.withAlphaComponent(0.14), accentColor.withAlphaComponent(0.08)]
                : [
                    NSColor.labelColor.withAlphaComponent(0.05),
                    NSColor.labelColor.withAlphaComponent(0.02),
                ],
            borderColor: nil,
            borderWidth: 0
        )
        iconView.image = appKitSymbolImage(
            named: isSelected ? leadingSelectedSymbol : leadingUnselectedSymbol,
            pointSize: 13,
            weight: isSelected ? .semibold : .regular,
            color: isSelected ? accentColor : .secondaryLabelColor
        )
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular)
        titleLabel.textColor = isSelected ? NSColor.labelColor : NSColor.secondaryLabelColor
        titleLabel.stringValue = rowTitle
        trailingImageView.image = trailingSelectedSymbol.flatMap {
            appKitSymbolImage(
                named: $0,
                pointSize: 11,
                weight: .bold,
                color: accentColor
            )
        }
        trailingImageView.isHidden = !isSelected || trailingSelectedSymbol == nil
    }

    var displayedTitleForTesting: String { titleLabel.stringValue }
}

final class AppKitPillButton: ActionButton {
    private let baseTitle: String
    private let textFont: NSFont
    private let unselectedTextColor: NSColor

    var selectedColor: NSColor {
        didSet { applySelectionState(isSelectedState) }
    }

    private(set) var isSelectedState: Bool = false

    init(
        title: String,
        isSelected: Bool,
        selectedColor: NSColor,
        unselectedTextColor: NSColor = .secondaryLabelColor,
        font: NSFont = .systemFont(ofSize: 11, weight: .bold)
    ) {
        baseTitle = title
        self.selectedColor = selectedColor
        self.unselectedTextColor = unselectedTextColor
        textFont = font
        super.init(title: title)

        isBordered = false
        layer?.cornerRadius = 6
        focusRingType = .none
        applySelectionState(isSelected)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applySelectionState(isSelectedState)
    }

    func applySelectionState(_ isSelected: Bool) {
        isSelectedState = isSelected
        setGradientBackground(
            colors: isSelected
                ? [selectedColor.withAlphaComponent(0.20), selectedColor.withAlphaComponent(0.12)]
                : [
                    NSColor.labelColor.withAlphaComponent(0.08),
                    NSColor.labelColor.withAlphaComponent(0.04),
                ],
            borderColor: nil,
            borderWidth: 0
        )
        attributedTitle = NSAttributedString(
            string: baseTitle,
            attributes: [
                .font: textFont,
                .foregroundColor: isSelected ? selectedColor : unselectedTextColor,
            ]
        )
    }
}

final class AppKitSymbolControlButton: ActionButton {
    private let iconView = NSImageView()
    private let symbolName: String
    private let symbolPointSize: CGFloat
    private let symbolWeight: NSFont.Weight

    var symbolColor: NSColor {
        didSet { updateSymbolImage() }
    }

    init(
        symbolName: String,
        pointSize: CGFloat,
        weight: NSFont.Weight,
        color: NSColor
    ) {
        self.symbolName = symbolName
        symbolPointSize = pointSize
        symbolWeight = weight
        symbolColor = color
        super.init(title: "")

        isBordered = false
        focusRingType = .none
        title = ""
        image = nil
        layer?.backgroundColor = nil
        layer?.borderWidth = 0
        (cell as? NSButtonCell)?.highlightsBy = []

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateSymbolImage()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateSymbolImage()
    }

    private func updateSymbolImage() {
        iconView.image = appKitSymbolImage(
            named: symbolName,
            pointSize: symbolPointSize,
            weight: symbolWeight,
            color: symbolColor
        )
    }

    var symbolNameForTesting: String { symbolName }
}

func configureAppKitIconButton(
    _ button: NSButton,
    symbolName: String,
    pointSize: CGFloat = 11,
    weight: NSFont.Weight = .semibold,
    color: NSColor = .secondaryLabelColor,
    backgroundColor: NSColor? = nil,
    cornerRadius: CGFloat = 0,
    imageInset: CGFloat = 0
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
    if let insetButton = button as? IconInsetButton {
        insetButton.imageInset = imageInset
    }
}

func configureAppKitIconButton(
    _ button: NSButton,
    symbol: AppKitUISymbolSpec,
    color: NSColor = .secondaryLabelColor,
    backgroundColor: NSColor? = nil,
    cornerRadius: CGFloat = 0,
    imageInset: CGFloat = 0
) {
    configureAppKitIconButton(
        button,
        symbolName: symbol.name,
        pointSize: symbol.pointSize,
        weight: symbol.weight,
        color: color,
        backgroundColor: backgroundColor,
        cornerRadius: cornerRadius,
        imageInset: imageInset
    )
}

func configureAppKitWindowButton(
    in window: NSWindow,
    type: NSWindow.ButtonType,
    controlSize: NSControl.ControlSize = .regular,
    targetSize: CGFloat? = nil,
    xOffset: CGFloat = 0,
    yOffset: CGFloat = 0
) {
    guard let button = window.standardWindowButton(type) else { return }
    let originalFrame = button.frame
    button.controlSize = controlSize
    guard let targetSize else { return }
    button.setFrameSize(NSSize(width: targetSize, height: targetSize))
    button.setFrameOrigin(
        NSPoint(
            x: originalFrame.origin.x - ((targetSize - originalFrame.width) / 2) + xOffset,
            y: originalFrame.origin.y - ((targetSize - originalFrame.height) / 2) + yOffset
        )
    )
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
) -> AppKitPillButton {
    let button = AppKitPillButton(
        title: title,
        isSelected: isSelected,
        selectedColor: selectedColor,
        unselectedTextColor: unselectedTextColor,
        font: font
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
    let resolvedSymbolName = resolvedAppKitControlSymbolName(symbol)
    let resolvedColor = isEnabled ? color : color.withAlphaComponent(0.45)
    let button = AppKitSymbolControlButton(
        symbolName: resolvedSymbolName,
        pointSize: pointSize,
        weight: .regular,
        color: resolvedColor
    )
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
    leadingSelectedSymbol: String = AppKitUISymbols.Name.linkSelected,
    leadingUnselectedSymbol: String = AppKitUISymbols.Name.link,
    trailingSelectedSymbol: String? = AppKitUISymbols.Name.checkmark,
    height: CGFloat = 34,
    action: @escaping () -> Void
) -> AppKitSelectableRowButton {
    let button = AppKitSelectableRowButton(
        title: title,
        isSelected: isSelected,
        accentColor: accentColor,
        leadingSelectedSymbol: leadingSelectedSymbol,
        leadingUnselectedSymbol: leadingUnselectedSymbol,
        trailingSelectedSymbol: trailingSelectedSymbol
    )
    button.onAction = action
    button.heightAnchor.constraint(equalToConstant: height).isActive = true
    return button
}

func makeAppKitDividerView(
    color: NSColor = NSColor.separatorColor.withAlphaComponent(0.4)
) -> NSView {
    let divider = AppKitDynamicView()
    divider.backgroundColorProvider = { color }
    divider.translatesAutoresizingMaskIntoConstraints = false
    divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
    return divider
}
