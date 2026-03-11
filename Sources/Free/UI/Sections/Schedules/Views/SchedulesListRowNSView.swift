import AppKit

final class SchedulesListRowNSView: NSView {
    var showsSeparator = true {
        didSet { needsDisplay = true }
    }

    private var schedule: Schedule?
    private var accentColorIndex: Int = 0
    private var onSelectSchedule: ((Schedule) -> Void)?
    private var onDeleteSchedule: ((UUID) -> Void)?
    private var onToggleScheduleEnabled: ((UUID, Bool) -> Void)?
    private let deleteButton = NSButton()
    private let toggleSwitch = NSSwitch()

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        deleteButton.isBordered = false
        deleteButton.image = appKitSymbolImage(
            spec: AppKitUISymbols.deleteRule,
            color: .systemRed
        )
        deleteButton.imagePosition = .imageOnly
        deleteButton.target = self
        deleteButton.action = #selector(deleteSchedule)

        toggleSwitch.controlSize = .small
        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggleScheduleEnabled)

        addSubview(deleteButton)
        addSubview(toggleSwitch)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        schedule: Schedule,
        accentColorIndex: Int,
        onSelectSchedule: ((Schedule) -> Void)?,
        onDeleteSchedule: ((UUID) -> Void)?,
        onToggleScheduleEnabled: ((UUID, Bool) -> Void)?
    ) {
        self.schedule = schedule
        self.accentColorIndex = accentColorIndex
        self.onSelectSchedule = onSelectSchedule
        self.onDeleteSchedule = onDeleteSchedule
        self.onToggleScheduleEnabled = onToggleScheduleEnabled

        toggleSwitch.state = schedule.isEnabled ? .on : .off
        deleteButton.isHidden = schedule.importedCalendarEventKey != nil

        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()

        let toggleSize = toggleSwitch.fittingSize
        let toggleOriginX = bounds.width - 18 - toggleSize.width
        toggleSwitch.frame = CGRect(
            x: toggleOriginX,
            y: floor((bounds.height - toggleSize.height) / 2),
            width: toggleSize.width,
            height: toggleSize.height
        )

        let deleteSize = CGSize(width: 24, height: 24)
        deleteButton.frame = CGRect(
            x: toggleSwitch.frame.minX - 12 - deleteSize.width,
            y: floor((bounds.height - deleteSize.height) / 2),
            width: deleteSize.width,
            height: deleteSize.height
        )
    }

    override func mouseUp(with event: NSEvent) {
        guard let schedule else { return }
        onSelectSchedule?(schedule)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let schedule else { return }

        if showsSeparator {
            NSColor.separatorColor.setStroke()
            let separator = NSBezierPath()
            separator.move(to: CGPoint(x: 0, y: bounds.maxY - 0.5))
            separator.line(to: CGPoint(x: bounds.maxX, y: bounds.maxY - 0.5))
            separator.stroke()
        }

        let indicatorColor =
            schedule.type == .focus
            ? FocusColor.nsColor(for: accentColorIndex)
            : appKitEmphasizedUnfocusColor(FocusColor.nsColor(for: schedule.colorIndex))
        let indicatorRect = CGRect(x: 16, y: 16, width: 4, height: bounds.height - 32)
        let indicatorPath = NSBezierPath(roundedRect: indicatorRect, xRadius: 2, yRadius: 2)
        indicatorColor.setFill()
        indicatorPath.fill()

        let contentLeft: CGFloat = 30
        let contentRight =
            deleteButton.isHidden
            ? toggleSwitch.frame.minX - 16
            : deleteButton.frame.minX - 16
        let availableWidth = max(contentRight - contentLeft, 0)

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.lineBreakMode = .byTruncatingTail

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: titleParagraph,
        ]
        let secondaryAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: titleParagraph,
        ]

        var titleX = contentLeft
        let titleY: CGFloat = 10

        if let typeImage = appKitSymbolImage(
            spec: schedule.type == .focus ? AppKitUISymbols.scheduleTypeFocus : AppKitUISymbols.scheduleTypeBreak,
            color: .secondaryLabelColor
        ) {
            let iconRect = CGRect(x: titleX, y: titleY + 2, width: 11, height: 11)
            typeImage.draw(in: iconRect)
            titleX = iconRect.maxX + 6
        }

        let importedBadgeWidth: CGFloat = schedule.importedCalendarEventKey == nil ? 0 : 72
        let titleRect = CGRect(
            x: titleX,
            y: titleY,
            width: max(availableWidth - (titleX - contentLeft) - importedBadgeWidth, 0),
            height: 16
        )
        (schedule.name as NSString).draw(in: titleRect, withAttributes: titleAttributes)

        if schedule.importedCalendarEventKey != nil {
            drawBadge(
                title: "Imported",
                in: CGRect(
                    x: max(titleRect.maxX + 8, contentLeft),
                    y: titleY - 1,
                    width: min(
                        importedBadgeWidth - 8, max(contentRight - titleRect.maxX - 8, 0)),
                    height: 18
                )
            )
        }

        let timeRect = CGRect(
            x: contentLeft,
            y: 30,
            width: availableWidth,
            height: 14
        )
        (schedule.timeRangeString as NSString).draw(
            in: timeRect,
            withAttributes: secondaryAttributes
        )

        drawTag(
            title: schedule.daysString,
            in: CGRect(
                x: contentLeft,
                y: 48,
                width: availableWidth,
                height: 18
            )
        )
    }

    @objc
    private func deleteSchedule() {
        guard let schedule else { return }
        onDeleteSchedule?(schedule.id)
    }

    @objc
    private func toggleScheduleEnabled() {
        guard let schedule else { return }
        onToggleScheduleEnabled?(schedule.id, toggleSwitch.state == .on)
    }

    private func drawBadge(title: String, in rect: CGRect) {
        guard rect.width > 24 else { return }

        let badgePath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        NSColor.secondaryLabelColor.withAlphaComponent(0.12).setFill()
        badgePath.fill()

        if let icon = appKitSymbolImage(
            spec: AppKitUISymbols.importedBadge,
            color: .secondaryLabelColor
        ) {
            let iconRect = CGRect(x: rect.minX + 6, y: rect.minY + 4, width: 10, height: 10)
            icon.draw(in: iconRect)

            let textRect = CGRect(
                x: iconRect.maxX + 4,
                y: rect.minY + 2,
                width: max(rect.width - 22, 0),
                height: rect.height - 4
            )
            (title as NSString).draw(
                in: textRect,
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
        }
    }

    private func drawTag(title: String, in rect: CGRect) {
        let tagAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]
        let textSize = (title as NSString).size(withAttributes: tagAttributes)
        let tagWidth = min(textSize.width + 12, rect.width)
        guard tagWidth > 0 else { return }

        let tagRect = CGRect(x: rect.minX, y: rect.minY, width: tagWidth, height: rect.height)
        let tagPath = NSBezierPath(roundedRect: tagRect, xRadius: 4, yRadius: 4)
        NSColor.secondaryLabelColor.withAlphaComponent(0.12).setFill()
        tagPath.fill()

        let textRect = CGRect(
            x: tagRect.minX + 6,
            y: tagRect.minY + 2,
            width: max(tagRect.width - 12, 0),
            height: tagRect.height - 4
        )
        (title as NSString).draw(in: textRect, withAttributes: tagAttributes)
    }
}
