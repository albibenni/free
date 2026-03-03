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
        layer?.cornerRadius = 12
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.borderWidth = 1

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
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

    var configured = baseImage.withSymbolConfiguration(.init(pointSize: pointSize, weight: weight))
    if let color {
        configured = configured?.withSymbolConfiguration(.init(paletteColors: [color]))
    }
    return configured ?? baseImage
}

func makeAppKitPrimaryButton(title: String, color: NSColor) -> ActionButton {
    let button = ActionButton(title: title)
    button.isBordered = false
    button.wantsLayer = true
    button.layer?.cornerRadius = 8
    button.layer?.backgroundColor = color.cgColor
    button.font = .systemFont(ofSize: 13, weight: .semibold)
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
    )
    return button
}

func makeAppKitSecondaryButton(title: String, color: NSColor) -> ActionButton {
    let button = ActionButton(title: title)
    button.isBordered = false
    button.wantsLayer = true
    button.layer?.cornerRadius = 8
    button.layer?.backgroundColor = color.withAlphaComponent(0.1).cgColor
    button.layer?.borderColor = color.withAlphaComponent(0.25).cgColor
    button.layer?.borderWidth = 1
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: color,
        ]
    )
    return button
}

func makeAppKitSectionLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 11, weight: .bold)
    label.textColor = .secondaryLabelColor
    return label
}
