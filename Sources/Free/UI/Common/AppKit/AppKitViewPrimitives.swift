import AppKit

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
