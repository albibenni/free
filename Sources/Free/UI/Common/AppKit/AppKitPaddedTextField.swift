import AppKit

final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    private let horizontalInset: CGFloat = 8

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var adjustedRect = super.drawingRect(forBounds: rect)
        if adjustedRect.width > (horizontalInset * 2) {
            adjustedRect.origin.x += horizontalInset
            adjustedRect.size.width -= horizontalInset * 2
        }
        let textSize = cellSize(forBounds: rect)
        let delta = floor((adjustedRect.height - textSize.height) / 2)
        if delta > 0 {
            adjustedRect.origin.y += delta
            adjustedRect.size.height -= delta * 2
        }
        return adjustedRect
    }

    override func edit(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        event: NSEvent?
    ) {
        super.edit(
            withFrame: drawingRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            event: event
        )
    }

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) {
        super.select(
            withFrame: drawingRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: selStart,
            length: selLength
        )
    }
}

final class VerticallyCenteredTextField: NSTextField {
    override class var cellClass: AnyClass? {
        get { VerticallyCenteredTextFieldCell.self }
        set { }
    }
}
