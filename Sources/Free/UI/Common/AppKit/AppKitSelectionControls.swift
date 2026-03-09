import AppKit

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
        let contentWidth = buttonWidths.values.reduce(CGFloat.zero, +)
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
        for (value, button) in buttons {
            let isSelected = value == selectedValue
            button.setGradientBackground(
                colors: isSelected
                    ? [accentColor.withAlphaComponent(0.20), accentColor.withAlphaComponent(0.12)]
                    : [NSColor.clear, NSColor.clear],
                borderColor: nil,
                borderWidth: 0
            )
            button.attributedTitle = NSAttributedString(
                string: button.title,
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
