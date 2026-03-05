import AppKit

func removeAllArrangedSubviews(from stackView: NSStackView) {
    let subviews = stackView.arrangedSubviews
    subviews.forEach { subview in
        stackView.removeArrangedSubview(subview)
        subview.removeFromSuperview()
    }
}

private final class StackFlippedContentView: NSView {
    override var isFlipped: Bool { true }
}

final class VerticalStackScrollContainer: NSScrollView {
    private let documentContainer = StackFlippedContentView()
    let stackView = NSStackView()
    private let stackInsets: NSEdgeInsets

    init(contentInsets: NSEdgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)) {
        stackInsets = contentInsets
        super.init(frame: .zero)

        drawsBackground = false
        borderType = .noBorder
        hasVerticalScroller = true
        autohidesScrollers = true

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12

        documentView = documentContainer
        documentContainer.addSubview(stackView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let width = max(contentSize.width, 1)
        let stackWidth = max(width - stackInsets.left - stackInsets.right, 1)
        let fittingSize = stackView.fittingSize
        let stackHeight = max(fittingSize.height, 1)

        documentContainer.frame = CGRect(
            x: 0,
            y: 0,
            width: width,
            height: max(
                stackHeight + stackInsets.top + stackInsets.bottom,
                contentSize.height
            )
        )
        stackView.frame = CGRect(
            x: stackInsets.left,
            y: stackInsets.top,
            width: stackWidth,
            height: stackHeight
        )
    }

    var usesFlippedDocumentCoordinatesForTesting: Bool {
        documentContainer.isFlipped
    }
}
