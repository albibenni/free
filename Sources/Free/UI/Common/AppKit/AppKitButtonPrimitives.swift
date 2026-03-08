import AppKit

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
        if let layer {
            backgroundGradientLayer.cornerRadius = layer.cornerRadius
        } else {
            backgroundGradientLayer.cornerRadius = 0
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        let hasGradientColors = gradientColors != nil
        let hasGradientBorderColor = gradientBorderColor != nil
        if hasGradientColors || hasGradientBorderColor {
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
        get {
            if let insetCell = cell as? IconInsetButtonCell {
                return insetCell.imageInset
            }
            return 0
        }
        set { (cell as? IconInsetButtonCell)?.imageInset = newValue }
    }
}

class LeadingInsetActionButton: ActionButton {
    override class var cellClass: AnyClass? {
        get { LeadingInsetButtonCell.self }
        set { }
    }

    var leadingInset: CGFloat {
        get {
            if let insetCell = cell as? LeadingInsetButtonCell {
                return insetCell.leadingInset
            }
            return 0
        }
        set { (cell as? LeadingInsetButtonCell)?.leadingInset = newValue }
    }

    var titleAdditionalInset: CGFloat {
        get {
            if let insetCell = cell as? LeadingInsetButtonCell {
                return insetCell.titleAdditionalInset
            }
            return 0
        }
        set { (cell as? LeadingInsetButtonCell)?.titleAdditionalInset = newValue }
    }

    var imageSlotWidth: CGFloat {
        get {
            if let insetCell = cell as? LeadingInsetButtonCell {
                return insetCell.imageSlotWidth
            }
            return 0
        }
        set { (cell as? LeadingInsetButtonCell)?.imageSlotWidth = newValue }
    }
}
