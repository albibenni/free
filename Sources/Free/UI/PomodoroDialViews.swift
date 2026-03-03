import AppKit

final class PomodoroDurationDialView: NSView {
    private let iconView = NSImageView()
    private let valueLabel = NSTextField(labelWithString: "")
    private let centerStack = NSStackView()
    private let maxMinutes: Double
    private let color: NSColor
    private let onInteractionDidBegin: (() -> Void)?
    private let onInteractionDidEnd: (() -> Void)?
    private let onCommit: (Double) -> Void
    private(set) var titleForTesting: String
    private(set) var durationMinutes: Double {
        didSet {
            valueLabel.stringValue = "\(Int(durationMinutes))m"
            needsDisplay = true
        }
    }
    private var isDragging = false

    override var intrinsicContentSize: NSSize {
        NSSize(width: 240, height: 240)
    }

    init(
        title: String,
        durationMinutes: Double,
        maxMinutes: Double,
        iconName: String,
        color: NSColor,
        onInteractionDidBegin: (() -> Void)? = nil,
        onInteractionDidEnd: (() -> Void)? = nil,
        onCommit: @escaping (Double) -> Void
    ) {
        self.titleForTesting = title
        self.durationMinutes = durationMinutes
        self.maxMinutes = maxMinutes
        self.color = color
        self.onInteractionDidBegin = onInteractionDidBegin
        self.onInteractionDidEnd = onInteractionDidEnd
        self.onCommit = onCommit
        super.init(frame: .zero)

        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        iconView.image = appKitSymbolImage(
            named: iconName,
            pointSize: 40,
            weight: .semibold,
            color: color.withAlphaComponent(0.92)
        )
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 42).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 42).isActive = true

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .bold)
        valueLabel.textColor = .labelColor
        valueLabel.alignment = .center
        valueLabel.stringValue = "\(Int(durationMinutes))m"

        centerStack.orientation = .vertical
        centerStack.alignment = .centerX
        centerStack.spacing = 8
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        centerStack.addArrangedSubview(iconView)
        centerStack.addArrangedSubview(valueLabel)
        addSubview(centerStack)

        NSLayoutConstraint.activate([
            centerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max((min(bounds.width, bounds.height) - PomodoroTimerSupport.Constants.strokeWidth) / 2, 0)
        guard radius > 0 else { return }

        let trackRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        let trackPath = NSBezierPath(ovalIn: trackRect)
        trackPath.lineWidth = PomodoroTimerSupport.Constants.strokeWidth
        NSColor.secondaryLabelColor.withAlphaComponent(PomodoroTimerSupport.Constants.trackOpacity).setStroke()
        trackPath.stroke()

        let progressFraction = CGFloat(max(0, min(durationMinutes / maxMinutes, 1)))
        let progressPath = NSBezierPath()
        progressPath.lineWidth = PomodoroTimerSupport.Constants.strokeWidth
        progressPath.lineCapStyle = .round
        progressPath.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - progressFraction * 360,
            clockwise: true
        )
        color.setStroke()
        progressPath.stroke()

        let knobRect = CGRect(
            origin: CGPoint(
                x: knobPosition(for: durationMinutes, radius: radius, center: center).x - PomodoroTimerSupport.Constants.knobSize / 2,
                y: knobPosition(for: durationMinutes, radius: radius, center: center).y - PomodoroTimerSupport.Constants.knobSize / 2
            ),
            size: CGSize(
                width: PomodoroTimerSupport.Constants.knobSize,
                height: PomodoroTimerSupport.Constants.knobSize
            )
        )
        let knobPath = NSBezierPath(ovalIn: knobRect)
        color.setFill()
        knobPath.fill()
        NSColor.white.setStroke()
        knobPath.lineWidth = 2
        knobPath.stroke()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        onInteractionDidBegin?()
        applyInteraction(at: convert(event.locationInWindow, from: nil), commit: false)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        applyInteraction(at: convert(event.locationInWindow, from: nil), commit: false)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        applyInteraction(at: convert(event.locationInWindow, from: nil), commit: true)
        isDragging = false
        onInteractionDidEnd?()
    }

    func applyLocationForTesting(_ point: CGPoint, commit: Bool = true) {
        applyInteraction(at: point, commit: commit)
    }

    var durationMinutesForTesting: Double { durationMinutes }

    private func applyInteraction(at point: CGPoint, commit: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let flippedPoint = CGPoint(x: point.x, y: bounds.height - point.y)
        let flippedCenter = CGPoint(x: center.x, y: bounds.height - center.y)
        let updatedDuration = PomodoroTimerSupport.calculateDuration(
            location: flippedPoint,
            center: flippedCenter,
            maxMinutes: maxMinutes
        )
        durationMinutes = updatedDuration
        if commit {
            onCommit(updatedDuration)
        }
    }

    private func knobPosition(for duration: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let fraction = duration / maxMinutes
        let angle = fraction * 2 * CGFloat.pi - (.pi / 2)
        return CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y - radius * sin(angle)
        )
    }
}

final class PomodoroProgressDialView: NSView {
    private let iconView = NSImageView()
    private let valueLabel = NSTextField(labelWithString: "")
    private let centerStack = NSStackView()
    private let progress: Double
    private let color: NSColor

    override var intrinsicContentSize: NSSize {
        NSSize(width: 240, height: 240)
    }

    init(
        progress: Double,
        iconName: String,
        color: NSColor,
        centerText: String
    ) {
        self.progress = max(0, min(progress, 1))
        self.color = color
        super.init(frame: .zero)

        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        iconView.image = appKitSymbolImage(
            named: iconName,
            pointSize: 40,
            weight: .semibold,
            color: color.withAlphaComponent(0.92)
        )
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 42).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 42).isActive = true

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .bold)
        valueLabel.textColor = .labelColor
        valueLabel.alignment = .center
        valueLabel.stringValue = centerText

        centerStack.orientation = .vertical
        centerStack.alignment = .centerX
        centerStack.spacing = 8
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        centerStack.addArrangedSubview(iconView)
        centerStack.addArrangedSubview(valueLabel)
        addSubview(centerStack)

        NSLayoutConstraint.activate([
            centerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max((min(bounds.width, bounds.height) - PomodoroTimerSupport.Constants.strokeWidth) / 2, 0)
        guard radius > 0 else { return }

        let trackRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        let trackPath = NSBezierPath(ovalIn: trackRect)
        trackPath.lineWidth = PomodoroTimerSupport.Constants.strokeWidth
        NSColor.secondaryLabelColor.withAlphaComponent(PomodoroTimerSupport.Constants.trackOpacity).setStroke()
        trackPath.stroke()

        let progressPath = NSBezierPath()
        progressPath.lineWidth = PomodoroTimerSupport.Constants.strokeWidth
        progressPath.lineCapStyle = .round
        progressPath.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - CGFloat(progress) * 360,
            clockwise: true
        )
        color.setStroke()
        progressPath.stroke()
    }
}
