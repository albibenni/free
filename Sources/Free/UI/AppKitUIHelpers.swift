import AppKit

class AppKitFlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class ActionButton: NSButton {
    var onAction: (() -> Void)?

    init(title: String = "", image: NSImage? = nil) {
        super.init(frame: .zero)
        self.title = title
        self.image = image
        target = self
        action = #selector(handleAction)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func handleAction() {
        onAction?()
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

func makeAppKitPrimaryButton(title: String, color: NSColor) -> ActionButton {
    let button = ActionButton(title: title)
    button.isBordered = false
    button.wantsLayer = true
    button.layer?.cornerRadius = AppKitUIConstants.CornerRadius.control
    button.layer?.backgroundColor = color.cgColor
    button.font = AppKitUIConstants.Typography.buttonLabel
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: AppKitUIConstants.Typography.buttonLabel,
            .foregroundColor: NSColor.white,
        ]
    )
    return button
}

func makeAppKitSecondaryButton(title: String, color: NSColor) -> ActionButton {
    let button = ActionButton(title: title)
    button.isBordered = false
    button.wantsLayer = true
    button.layer?.cornerRadius = AppKitUIConstants.CornerRadius.control
    button.layer?.backgroundColor = color.withAlphaComponent(0.1).cgColor
    button.layer?.borderColor = color.withAlphaComponent(0.25).cgColor
    button.layer?.borderWidth = 1
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: AppKitUIConstants.Typography.regular,
            .foregroundColor: color,
        ]
    )
    return button
}

func makeAppKitSectionLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = AppKitUIConstants.Typography.helperLabel
    label.textColor = .secondaryLabelColor
    return label
}
