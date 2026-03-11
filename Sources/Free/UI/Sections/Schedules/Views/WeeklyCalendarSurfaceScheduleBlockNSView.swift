import AppKit

final class WeeklyCalendarSurfaceScheduleBlockNSView: NSView {
    private var entry: WeeklyCalendarSupport.PositionedSchedule?
    private var originalFrame: CGRect = .zero
    private var columnWidth: CGFloat = 0
    private var originalColumnIndex: Int = 0
    private var calendarAreaX: CGFloat = 0
    private var dayCount: Int = 7
    private var weekRange: [Date] = []
    private var hourHeight: CGFloat = 80
    private var edgeHeight: CGFloat = 18
    private var onOpenSchedule: ((Int, Schedule) -> Void)?
    private var onUpdateSchedule: ((UUID, Int, Int, Date?, Date, Date) -> Void)?
    private var onInteractionDidBegin: ((String) -> Void)?
    private var onInteractionDidEnd: ((Bool) -> Void)?
    private var mouseDownPointInWindow: CGPoint = .zero
    private var interactionMode: WeeklyCalendarSupport.ScheduleInteractionMode?
    private var hasDragged = false
    private var isInteractionActive = false
    private var interactionPreviewLabels: (start: String, end: String)?

    override var isFlipped: Bool { true }

    func configure(
        entry: WeeklyCalendarSupport.PositionedSchedule,
        frame: CGRect,
        columnWidth: CGFloat,
        originalColumnIndex: Int,
        calendarAreaX: CGFloat,
        dayCount: Int,
        weekRange: [Date],
        hourHeight: CGFloat,
        edgeHeight: CGFloat,
        onOpenSchedule: @escaping (Int, Schedule) -> Void,
        onUpdateSchedule: @escaping (UUID, Int, Int, Date?, Date, Date) -> Void,
        onInteractionDidBegin: @escaping (String) -> Void,
        onInteractionDidEnd: @escaping (Bool) -> Void
    ) {
        self.entry = entry
        self.originalFrame = frame
        self.columnWidth = columnWidth
        self.originalColumnIndex = originalColumnIndex
        self.calendarAreaX = calendarAreaX
        self.dayCount = dayCount
        self.weekRange = weekRange
        self.hourHeight = hourHeight
        self.edgeHeight = edgeHeight
        self.onOpenSchedule = onOpenSchedule
        self.onUpdateSchedule = onUpdateSchedule
        self.onInteractionDidBegin = onInteractionDidBegin
        self.onInteractionDidEnd = onInteractionDidEnd
        interactionPreviewLabels = nil
        self.frame = frame
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let entry else { return }

        if WeeklyCalendarSupport.canDirectlyManipulate(entry.schedule) {
            let handleHeight = WeeklyCalendarSupport.effectiveResizeHandleHeight(
                boundsHeight: bounds.height,
                preferredHeight: edgeHeight
            )
            addCursorRect(
                CGRect(x: 0, y: 0, width: bounds.width, height: handleHeight),
                cursor: .resizeUpDown
            )
            addCursorRect(
                CGRect(
                    x: 0,
                    y: max(bounds.height - handleHeight, 0),
                    width: bounds.width,
                    height: handleHeight
                ),
                cursor: .resizeUpDown
            )
            let bodyRect = CGRect(
                x: 0,
                y: handleHeight,
                width: bounds.width,
                height: max(bounds.height - handleHeight * 2, 0)
            )
            if bodyRect.height > 0 {
                addCursorRect(bodyRect, cursor: .openHand)
            }
        } else {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let entry else { return }
        mouseDownPointInWindow = event.locationInWindow
        hasDragged = false
        setInteractionPreviewLabels(nil)

        if WeeklyCalendarSupport.canDirectlyManipulate(entry.schedule) {
            let localPoint = convert(event.locationInWindow, from: nil)
            interactionMode = WeeklyCalendarSupport.interactionMode(
                at: localPoint,
                in: bounds,
                edgeHeight: edgeHeight
            )
            isInteractionActive = true
            onInteractionDidBegin?(entry.id)
            superview?.addSubview(self, positioned: .above, relativeTo: nil)
        } else {
            interactionMode = nil
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            let entry,
            WeeklyCalendarSupport.canDirectlyManipulate(entry.schedule),
            let interactionMode
        else {
            return
        }

        let translation = translation(for: event)
        let snapped: CGSize
        switch interactionMode {
        case .move:
            let dayDelta = dayDelta(for: event)
            let snappedY =
                CGFloat(
                    WeeklyCalendarSupport.snappedMinuteDelta(
                        translationHeight: translation.height,
                        hourHeight: hourHeight
                    )
                ) * hourHeight / 60
            snapped = CGSize(width: CGFloat(dayDelta) * columnWidth, height: snappedY)
        case .resizeStart, .resizeEnd:
            snapped = WeeklyCalendarSupport.snappedInteractionTranslation(
                translation: translation,
                mode: interactionMode,
                columnWidth: columnWidth,
                hourHeight: hourHeight
            )
        }
        hasDragged = abs(snapped.width) > 0 || abs(snapped.height) > 0
        if hasDragged {
            setInteractionPreviewLabels(
                WeeklyCalendarSupport.schedulePreviewLabels(
                    placement: entry.placement,
                    translation: snapped,
                    mode: interactionMode,
                    hourHeight: hourHeight
                )
            )
        } else {
            setInteractionPreviewLabels(nil)
        }

        let previewFrame = WeeklyCalendarSupport.previewFrame(
            baseFrame: originalFrame,
            translation: snapped,
            mode: interactionMode
        )
        if frame != previewFrame {
            frame = previewFrame
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            interactionMode = nil
            hasDragged = false
            isInteractionActive = false
            setInteractionPreviewLabels(nil)
        }

        guard let entry else { return }

        if hasDragged, let interactionMode {
            let update = WeeklyCalendarSupport.scheduleUpdate(
                placement: entry.placement,
                translation: translation(for: event),
                mode: interactionMode,
                columnWidth: columnWidth,
                hourHeight: hourHeight,
                weekRange: weekRange,
                resolvedDayDelta: interactionMode == .move ? dayDelta(for: event) : nil
            )!
            onUpdateSchedule?(
                entry.schedule.id,
                entry.placement.day,
                update.targetDay,
                update.targetDate,
                update.start,
                update.end
            )
            finishInteraction(rebuildImmediately: false)
            return
        }

        onOpenSchedule?(entry.placement.day, entry.schedule)
        finishInteraction(rebuildImmediately: true)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let entry else { return }

        let schedule = entry.schedule
        let isImported = schedule.importedCalendarEventKey != nil
        let fillColor: NSColor
        let borderColor: NSColor

        if !schedule.isEnabled {
            fillColor = NSColor.systemGray.withAlphaComponent(0.5)
            borderColor = NSColor.systemGray.withAlphaComponent(0.8)
        } else {
            let baseColor = {
                let raw = FocusColor.nsColor(for: schedule.colorIndex)
                return schedule.type == .unfocus ? appKitEmphasizedUnfocusColor(raw) : raw
            }()
            fillColor = baseColor.withAlphaComponent(
                WeeklyCalendarSupport.blockFillOpacity(isImported: isImported)
            )
            borderColor = baseColor.withAlphaComponent(
                WeeklyCalendarSupport.blockBorderOpacity(isImported: isImported)
            )
        }

        let roundedRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: roundedRect, xRadius: 6, yRadius: 6)
        fillColor.setFill()
        path.fill()
        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        if let interactionPreviewLabels {
            drawInteractionPreviewLabels(interactionPreviewLabels)
            return
        }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9),
        ]

        let titleLineRect = CGRect(x: 6, y: 6, width: bounds.width - 12, height: 14)
        var titleMinX = titleLineRect.minX
        var titleMaxX = titleLineRect.maxX

        if let typeIcon = appKitSymbolImage(
            named: WeeklyCalendarSupport.primarySymbolName(for: schedule),
            pointSize: 10,
            weight: .bold,
            color: .white
        ) {
            let iconRect = CGRect(
                x: titleMinX,
                y: titleLineRect.midY - 5,
                width: 10,
                height: 10
            )
            typeIcon.draw(in: iconRect)
            titleMinX = iconRect.maxX + 4
        }

        if let importedSymbolName = WeeklyCalendarSupport.importedSymbolName(for: schedule),
           let importedIcon = appKitSymbolImage(
                named: importedSymbolName,
                pointSize: 9,
                weight: .bold,
                color: .white
           ) {
            let iconRect = CGRect(
                x: titleMaxX - 10,
                y: titleLineRect.midY - 5,
                width: 10,
                height: 10
            )
            importedIcon.draw(in: iconRect)
            titleMaxX = iconRect.minX - 4
        }

        let titleRect = CGRect(
            x: titleMinX,
            y: titleLineRect.minY,
            width: max(titleMaxX - titleMinX, 0),
            height: titleLineRect.height
        )
        (schedule.name as NSString).draw(in: titleRect, withAttributes: titleAttributes)

        let timeRect = CGRect(x: 6, y: 20, width: bounds.width - 12, height: 12)
        (schedule.timeRangeString as NSString).draw(in: timeRect, withAttributes: timeAttributes)
    }

    private func translation(for event: NSEvent) -> CGSize {
        CGSize(
            width: event.locationInWindow.x - mouseDownPointInWindow.x,
            height: mouseDownPointInWindow.y - event.locationInWindow.y
        )
    }

    private func dayDelta(for event: NSEvent) -> Int {
        guard let superview else { return 0 }
        let pointInDocument = superview.convert(event.locationInWindow, from: nil)
        return WeeklyCalendarSupport.dayDelta(
            cursorX: pointInDocument.x,
            calendarAreaX: calendarAreaX,
            columnWidth: columnWidth,
            dayCount: dayCount,
            originalColumnIndex: originalColumnIndex
        )
    }

    private func finishInteraction(rebuildImmediately: Bool) {
        guard isInteractionActive else { return }
        onInteractionDidEnd?(rebuildImmediately)
    }

    private func drawInteractionPreviewLabels(_ labels: (start: String, end: String)) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineBreakMode = .byTruncatingTail
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.95),
            .paragraphStyle: paragraph,
        ]

        let labelHeight: CGFloat = 14
        let horizontalInset: CGFloat = 6
        let verticalInset: CGFloat = 6
        let textWidth = max(bounds.width - horizontalInset * 2, 0)

        let startRect = CGRect(
            x: horizontalInset,
            y: verticalInset,
            width: textWidth,
            height: labelHeight
        )
        (labels.start as NSString).draw(in: startRect, withAttributes: textAttributes)

        let endRect = CGRect(
            x: horizontalInset,
            y: max(bounds.height - verticalInset - labelHeight, startRect.maxY),
            width: textWidth,
            height: labelHeight
        )
        (labels.end as NSString).draw(in: endRect, withAttributes: textAttributes)
    }

    private func setInteractionPreviewLabels(_ labels: (start: String, end: String)?) {
        let didChange =
            interactionPreviewLabels?.start != labels?.start
            || interactionPreviewLabels?.end != labels?.end
        interactionPreviewLabels = labels
        if didChange {
            needsDisplay = true
        }
    }
}
