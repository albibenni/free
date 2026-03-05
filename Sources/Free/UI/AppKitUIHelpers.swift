import AppKit

func resolvedAppKitCGColor(_ color: NSColor, appearance: NSAppearance?) -> CGColor {
    guard let appearance else { return color.cgColor }
    var resolvedColor = color.cgColor
    appearance.performAsCurrentDrawingAppearance {
        resolvedColor = color.cgColor
    }
    return resolvedColor
}

func resolvedAppKitCGColor(
    _ colorProvider: @escaping () -> NSColor?,
    appearance: NSAppearance?
) -> CGColor? {
    guard let appearance else { return colorProvider()?.cgColor }
    var resolvedColor: CGColor?
    appearance.performAsCurrentDrawingAppearance {
        resolvedColor = colorProvider()?.cgColor
    }
    return resolvedColor
}

class AppKitDynamicView: NSView {
    var backgroundColorProvider: (() -> NSColor?)? {
        didSet { applyDynamicLayerColors() }
    }

    var borderColorProvider: (() -> NSColor?)? {
        didSet { applyDynamicLayerColors() }
    }

    var borderWidthValue: CGFloat = 0 {
        didSet { applyDynamicLayerColors() }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyDynamicLayerColors()
    }

    func applyDynamicLayerColors() {
        guard backgroundColorProvider != nil || borderColorProvider != nil || borderWidthValue > 0 else {
            return
        }
        wantsLayer = true
        layer?.backgroundColor = backgroundColorProvider.flatMap {
            resolvedAppKitCGColor($0, appearance: effectiveAppearance)
        }
        layer?.borderColor = borderColorProvider.flatMap {
            resolvedAppKitCGColor($0, appearance: effectiveAppearance)
        }
        layer?.borderWidth = borderWidthValue
    }
}

class AppKitFlippedView: AppKitDynamicView {
    override var isFlipped: Bool { true }
}

final class AppKitCardStackView: NSStackView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        applyAppearanceColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearanceColors()
    }

    func applyAppearanceColors() {
        layer?.backgroundColor = resolvedAppKitCGColor(
            NSColor.controlBackgroundColor,
            appearance: effectiveAppearance
        )
    }
}

struct AppKitSelectionButtonOption<Value: Hashable> {
    let title: String
    let value: Value
}

final class AppKitSelectionButtonGroup<Value: Hashable>: AppKitFlippedView {
    private let stackView = NSStackView()
    private let options: [AppKitSelectionButtonOption<Value>]
    private var buttons: [Value: ActionButton] = [:]
    private var buttonWidths: [Value: CGFloat] = [:]
    private let buttonHeight: CGFloat = 24
    private let controlInset: CGFloat = 1
    private let buttonSpacing: CGFloat = 1

    var accentColor: NSColor {
        didSet { updateButtonStyles() }
    }

    var selectedValue: Value {
        didSet { updateButtonStyles() }
    }

    var onSelection: ((Value) -> Void)?

    init(
        options: [AppKitSelectionButtonOption<Value>],
        selectedValue: Value,
        accentColor: NSColor = .controlAccentColor
    ) {
        self.options = options
        self.selectedValue = selectedValue
        self.accentColor = accentColor
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 7

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 1
        stackView.edgeInsets = NSEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        buildButtons()
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        updateButtonStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let contentWidth = options.reduce(CGFloat.zero) { partialResult, option in
            partialResult + (buttonWidths[option.value] ?? 0)
        }
        let spacingWidth = max(CGFloat(options.count - 1), 0) * buttonSpacing
        return NSSize(
            width: contentWidth + spacingWidth + (controlInset * 2),
            height: buttonHeight + (controlInset * 2)
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateButtonStyles()
    }

    var selectedButtonTintColor: NSColor? {
        buttons[selectedValue]?.contentTintColor
    }

    private func buildButtons() {
        for option in options {
            let button = ActionButton(title: option.title)
            button.isBordered = false
            button.layer?.cornerRadius = 6
            button.translatesAutoresizingMaskIntoConstraints = false
            let width = ceil((option.title as NSString).size(withAttributes: [
                .font: AppKitUIConstants.Typography.regular,
            ]).width) + 20
            buttonWidths[option.value] = width
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
            button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
            button.onAction = { [weak self] in
                self?.handleSelection(option.value)
            }
            stackView.addArrangedSubview(button)
            buttons[option.value] = button
        }
        invalidateIntrinsicContentSize()
    }

    private func handleSelection(_ value: Value) {
        selectedValue = value
        onSelection?(value)
    }

    private func updateButtonStyles() {
        layer?.backgroundColor = resolvedAppKitCGColor(
            NSColor.labelColor.withAlphaComponent(0.08),
            appearance: effectiveAppearance
        )
        for option in options {
            guard let button = buttons[option.value] else { continue }
            let isSelected = option.value == selectedValue
            button.setGradientBackground(
                colors: isSelected
                    ? [accentColor.withAlphaComponent(0.20), accentColor.withAlphaComponent(0.12)]
                    : [NSColor.clear, NSColor.clear],
                borderColor: nil,
                borderWidth: 0
            )
            button.attributedTitle = NSAttributedString(
                string: option.title,
                attributes: [
                    .font: AppKitUIConstants.Typography.regular,
                    .foregroundColor: isSelected ? accentColor : NSColor.labelColor,
                ]
            )
            button.contentTintColor = isSelected ? accentColor : .labelColor
        }
    }
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

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
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
    private var gradientColors: [NSColor]?
    private var gradientBorderColor: NSColor?
    private var gradientBorderWidth: CGFloat = 1

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

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if gradientColors != nil || gradientBorderColor != nil {
            applyStoredGradient()
        }
    }

    func setGradientBackground(
        colors: [NSColor],
        borderColor: NSColor? = nil,
        borderWidth: CGFloat = 1
    ) {
        gradientColors = colors
        gradientBorderColor = borderColor
        gradientBorderWidth = borderWidth
        applyStoredGradient()
    }

    private func applyStoredGradient() {
        backgroundGradientLayer.isHidden = false
        backgroundGradientLayer.colors = gradientColors?.map {
            resolvedAppKitCGColor($0, appearance: effectiveAppearance)
        }
        layer?.backgroundColor = nil
        layer?.borderColor = gradientBorderColor.map {
            resolvedAppKitCGColor($0, appearance: effectiveAppearance)
        }
        layer?.borderWidth = gradientBorderWidth
        needsLayout = true
    }
}

final class LeadingInsetButtonCell: NSButtonCell {
    var leadingInset: CGFloat = 8
    var titleAdditionalInset: CGFloat = 8
    var imageSlotWidth: CGFloat = 16

    override func imageRect(forBounds rect: NSRect) -> NSRect {
        var imageRect = super.imageRect(forBounds: rect)
        let slotX = leadingInset
        imageRect.origin.x = slotX + floor((imageSlotWidth - imageRect.width) / 2)
        return imageRect
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)
        let totalInset = leadingInset + imageSlotWidth + titleAdditionalInset
        titleRect.origin.x = rect.minX + totalInset
        titleRect.size.width = max(rect.width - totalInset, 0)
        return titleRect
    }
}

final class IconInsetButtonCell: NSButtonCell {
    var imageInset: CGFloat = 0

    override func imageRect(forBounds rect: NSRect) -> NSRect {
        let insetBounds = rect.insetBy(dx: imageInset, dy: imageInset)
        return super.imageRect(forBounds: insetBounds)
    }
}

final class IconInsetButton: NSButton {
    override class var cellClass: AnyClass? {
        get { IconInsetButtonCell.self }
        set { }
    }

    var imageInset: CGFloat {
        get { (cell as? IconInsetButtonCell)?.imageInset ?? 0 }
        set { (cell as? IconInsetButtonCell)?.imageInset = newValue }
    }
}

class LeadingInsetActionButton: ActionButton {
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

    var imageSlotWidth: CGFloat {
        get { (cell as? LeadingInsetButtonCell)?.imageSlotWidth ?? 0 }
        set { (cell as? LeadingInsetButtonCell)?.imageSlotWidth = newValue }
    }
}

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
        leadingSelectedSymbol: String = "link.circle.fill",
        leadingUnselectedSymbol: String = "link",
        trailingSelectedSymbol: String? = "checkmark"
    ) {
        self.rowTitle = title
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
        self.baseTitle = title
        self.selectedColor = selectedColor
        self.unselectedTextColor = unselectedTextColor
        self.textFont = font
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
        self.symbolPointSize = pointSize
        self.symbolWeight = weight
        self.symbolColor = color
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

class AppKitCardView: AppKitFlippedView {
    let contentStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        backgroundColorProvider = { NSColor.controlBackgroundColor.withAlphaComponent(0.8) }
        layer?.cornerRadius = AppKitUIConstants.CornerRadius.card
        borderColorProvider = { NSColor.separatorColor.withAlphaComponent(0.35) }
        borderWidthValue = 1

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
    leadingSelectedSymbol: String = "link.circle.fill",
    leadingUnselectedSymbol: String = "link",
    trailingSelectedSymbol: String? = "checkmark",
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
