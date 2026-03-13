import AppKit

final class WeeklyCalendarSurfaceDocumentNSView: NSView {
    private var configuration: WeeklyCalendarSurfaceConfiguration?
    private var scheduleBlockViews: [String: WeeklyCalendarSurfaceScheduleBlockNSView] = [:]
    private var selectionDay: Int?
    private var selectionStartPoint: CGPoint = .zero
    private var selectionCurrentPoint: CGPoint = .zero
    private var isSelecting = false
    private var timer: Timer?
    private var activeInteractionBlockID: String?
    private var needsScheduleBlockRefresh = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = resolvedAppKitCGColor(
            NSColor.windowBackgroundColor,
            appearance: effectiveAppearance
        )
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        timer?.invalidate()
    }

    func configure(with configuration: WeeklyCalendarSurfaceConfiguration) {
        self.configuration = configuration
        layer?.backgroundColor = resolvedAppKitCGColor(
            NSColor.windowBackgroundColor,
            appearance: effectiveAppearance
        )
        if activeInteractionBlockID == nil {
            rebuildScheduleBlocks()
            needsScheduleBlockRefresh = false
        } else {
            needsScheduleBlockRefresh = true
        }
        needsDisplay = true
    }

    func applyCurrentLayout() {
        if activeInteractionBlockID == nil {
            rebuildScheduleBlocks()
            needsScheduleBlockRefresh = false
        } else {
            needsScheduleBlockRefresh = true
        }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard let configuration else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard let day = dayForPoint(point, configuration: configuration) else { return }

        selectionDay = day
        selectionStartPoint = point
        selectionCurrentPoint = point
        isSelecting = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard selectionDay != nil else { return }
        selectionCurrentPoint = convert(event.locationInWindow, from: nil)
        if !isSelecting {
            isSelecting =
                abs(selectionCurrentPoint.x - selectionStartPoint.x) > 5
                || abs(selectionCurrentPoint.y - selectionStartPoint.y) > 5
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let configuration, let day = selectionDay else {
            clearSelection()
            return
        }

        let endPoint = convert(event.locationInWindow, from: nil)
        selectionCurrentPoint = endPoint

        if isSelecting {
            let startHour = selectionStartPoint.y / configuration.hourHeight
            let endHour = selectionCurrentPoint.y / configuration.hourHeight
            configuration.onCreateSelection(day, startHour, endHour)
        } else {
            let hour = max(0, min(23, Int(endPoint.y / configuration.hourHeight)))
            configuration.onQuickAdd(day, hour)
        }

        clearSelection()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let configuration else { return }

        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        drawHourGrid(configuration: configuration)
        drawDayDividers(configuration: configuration)
        drawExternalEvents(configuration: configuration)
        drawSelectionPreview(configuration: configuration)
        drawCurrentTimeIndicator(configuration: configuration)
    }

    private func rebuildScheduleBlocks() {
        guard let configuration else { return }

        scheduleBlockViews.values.forEach { $0.removeFromSuperview() }
        scheduleBlockViews.removeAll()

        let columnWidth = dayColumnWidth(configuration: configuration)
        let calendarX = calendarAreaX(configuration: configuration)

        for entry in configuration.positionedSchedules {
            guard
                let columnIndex = configuration.dayOrder.firstIndex(of: entry.placement.day),
                let frame = WeeklyCalendarSupport.calculateRect(
                    startDate: entry.placement.startDate,
                    endDate: entry.placement.endDate,
                    colIndex: columnIndex,
                    columnWidth: columnWidth,
                    laneIndex: entry.laneIndex,
                    laneCount: entry.laneCount,
                    hourHeight: configuration.hourHeight
                )
            else {
                continue
            }

            var adjustedFrame = frame
            adjustedFrame.origin.x += calendarX

            let blockView = WeeklyCalendarSurfaceScheduleBlockNSView()
            blockView.configure(
                entry: entry,
                frame: adjustedFrame,
                columnWidth: columnWidth,
                originalColumnIndex: columnIndex,
                calendarAreaX: calendarX,
                dayCount: configuration.dayOrder.count,
                weekRange: configuration.weekRange,
                hourHeight: configuration.hourHeight,
                edgeHeight: 18,
                onOpenSchedule: configuration.onOpenSchedule,
                onUpdateSchedule: configuration.onUpdateSchedule,
                onInteractionDidBegin: { [weak self] id in
                    self?.scheduleInteractionDidBegin(id: id)
                },
                onInteractionDidEnd: { [weak self] rebuildImmediately in
                    self?.scheduleInteractionDidEnd(rebuildImmediately: rebuildImmediately)
                }
            )
            addSubview(blockView)
            scheduleBlockViews[entry.id] = blockView
        }
    }

    private func scheduleInteractionDidBegin(id: String) {
        activeInteractionBlockID = id
    }

    private func scheduleInteractionDidEnd(rebuildImmediately: Bool) {
        activeInteractionBlockID = nil
        guard needsScheduleBlockRefresh else { return }
        guard rebuildImmediately else { return }

        rebuildScheduleBlocks()
        needsScheduleBlockRefresh = false
        needsDisplay = true
    }

    private func clearSelection() {
        selectionDay = nil
        isSelecting = false
        needsDisplay = true
    }

    private func drawHourGrid(configuration: WeeklyCalendarSurfaceConfiguration) {
        let calendarX = calendarAreaX(configuration: configuration)
        let labelParagraph = NSMutableParagraphStyle()
        labelParagraph.alignment = .right
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: labelParagraph,
        ]

        for hour in 0..<24 {
            let y = CGFloat(hour) * configuration.hourHeight
            NSColor.separatorColor.setStroke()
            let line = NSBezierPath()
            line.move(to: CGPoint(x: 0, y: y))
            line.line(to: CGPoint(x: bounds.width, y: y))
            line.stroke()

            let text = WeeklyCalendarSupport.timeString(hour: hour) as NSString
            let textRect = CGRect(
                x: 8,
                y: y - 6,
                width: max(configuration.timeLabelWidth - 12, 0),
                height: 14
            )
            text.draw(in: textRect, withAttributes: labelAttributes)
        }

        NSColor.separatorColor.setStroke()
        let gutterLine = NSBezierPath()
        gutterLine.move(to: CGPoint(x: calendarX, y: 0))
        gutterLine.line(to: CGPoint(x: calendarX, y: bounds.height))
        gutterLine.stroke()
    }

    private func drawDayDividers(configuration: WeeklyCalendarSurfaceConfiguration) {
        let calendarX = calendarAreaX(configuration: configuration)
        let columnWidth = dayColumnWidth(configuration: configuration)

        for index in 0...7 {
            let x = calendarX + CGFloat(index) * columnWidth
            NSColor.separatorColor.setStroke()
            let line = NSBezierPath()
            line.move(to: CGPoint(x: x, y: 0))
            line.line(to: CGPoint(x: x, y: bounds.height))
            line.stroke()
        }
    }

    private func drawExternalEvents(configuration: WeeklyCalendarSurfaceConfiguration) {
        guard configuration.showsExternalEvents else { return }

        let calendarX = calendarAreaX(configuration: configuration)
        let columnWidth = dayColumnWidth(configuration: configuration)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        for event in configuration.externalEvents {
            let weekday = Calendar.current.component(.weekday, from: event.startDate)
            guard
                let columnIndex = configuration.dayOrder.firstIndex(of: weekday),
                let frame = WeeklyCalendarSupport.calculateRect(
                    startDate: event.startDate,
                    endDate: event.endDate,
                    colIndex: columnIndex,
                    columnWidth: columnWidth,
                    hourHeight: configuration.hourHeight
                )
            else {
                continue
            }

            var adjustedFrame = frame
            adjustedFrame.origin.x += calendarX

            let path = NSBezierPath(roundedRect: adjustedFrame, xRadius: 6, yRadius: 6)
            NSColor.secondaryLabelColor.withAlphaComponent(0.12).setFill()
            path.fill()

            NSColor.secondaryLabelColor.withAlphaComponent(0.4).setStroke()
            let dashed = path.copy() as! NSBezierPath
            dashed.setLineDash([4, 4], count: 2, phase: 0)
            dashed.stroke()

            (event.title as NSString).draw(
                in: adjustedFrame.insetBy(dx: 6, dy: 4),
                withAttributes: titleAttributes
            )
        }
    }

    private func drawSelectionPreview(configuration: WeeklyCalendarSurfaceConfiguration) {
        guard
            isSelecting,
            let day = selectionDay,
            let columnIndex = configuration.dayOrder.firstIndex(of: day)
        else {
            return
        }

        let startHour = selectionStartPoint.y / configuration.hourHeight
        let endHour = selectionCurrentPoint.y / configuration.hourHeight
        let (snappedStart, snappedEnd) = WeeklyCalendarSupport.snappedSelectionHours(
            startHour: startHour,
            endHour: endHour
        )
        let rect = CGRect(
            x: calendarAreaX(configuration: configuration) + CGFloat(columnIndex)
                * dayColumnWidth(configuration: configuration) + 2,
            y: snappedStart * configuration.hourHeight,
            width: dayColumnWidth(configuration: configuration) - 4,
            height: (snappedEnd - snappedStart) * configuration.hourHeight
        )

        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        if let gradient = appKitAccentGradient(for: configuration.accentColor, alpha: 0.25) {
            gradient.draw(in: path, angle: 0)
        } else {
            configuration.accentColor.withAlphaComponent(0.25).setFill()
            path.fill()
        }

        let labels = WeeklyCalendarSupport.selectionPreviewLabels(
            startHour: startHour,
            endHour: endHour
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineBreakMode = .byTruncatingTail
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.gray.withAlphaComponent(0.8),
            .paragraphStyle: paragraph,
        ]

        let labelHeight: CGFloat = 14
        let horizontalInset: CGFloat = 6
        let verticalInset: CGFloat = 6
        let textWidth = max(rect.width - horizontalInset * 2, 0)

        let startRect = CGRect(
            x: rect.minX + horizontalInset,
            y: rect.minY + verticalInset,
            width: textWidth,
            height: labelHeight
        )
        (labels.start as NSString).draw(in: startRect, withAttributes: textAttributes)

        let endRect = CGRect(
            x: rect.minX + horizontalInset,
            y: max(rect.maxY - verticalInset - labelHeight, startRect.maxY),
            width: textWidth,
            height: labelHeight
        )
        (labels.end as NSString).draw(in: endRect, withAttributes: textAttributes)
    }

    private func drawCurrentTimeIndicator(configuration: WeeklyCalendarSurfaceConfiguration) {
        let now = Date()
        guard now >= configuration.weekStart, now < configuration.weekEnd else { return }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let weekday = calendar.component(.weekday, from: now)
        guard let dayIndex = configuration.dayOrder.firstIndex(of: weekday) else { return }

        let y = (CGFloat(hour) + CGFloat(minute) / 60) * configuration.hourHeight
        let x =
            calendarAreaX(configuration: configuration)
            + CGFloat(dayIndex) * dayColumnWidth(configuration: configuration)
        let width = dayColumnWidth(configuration: configuration)

        let dotRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
        if let gradient = appKitAccentGradient(for: configuration.accentColor, alpha: 0.95) {
            let dotPath = NSBezierPath(ovalIn: dotRect)
            gradient.draw(in: dotPath, angle: 0)
            appKitAccentPrimaryColor(for: configuration.accentColor).setStroke()
            let line = NSBezierPath()
            line.lineWidth = 1
            line.move(to: CGPoint(x: x, y: y))
            line.line(to: CGPoint(x: x + width, y: y))
            line.stroke()
        } else {
            configuration.accentColor.setFill()
            NSBezierPath(ovalIn: dotRect).fill()

            configuration.accentColor.setStroke()
            let line = NSBezierPath()
            line.lineWidth = 1
            line.move(to: CGPoint(x: x, y: y))
            line.line(to: CGPoint(x: x + width, y: y))
            line.stroke()
        }
    }

    private func calendarAreaX(configuration: WeeklyCalendarSurfaceConfiguration) -> CGFloat {
        configuration.timeLabelWidth + configuration.timeColumnGutter
    }

    private func dayColumnWidth(configuration: WeeklyCalendarSurfaceConfiguration) -> CGFloat {
        max((bounds.width - calendarAreaX(configuration: configuration)) / 7, 1)
    }

    private func dayForPoint(
        _ point: CGPoint,
        configuration: WeeklyCalendarSurfaceConfiguration
    ) -> Int? {
        let calendarX = calendarAreaX(configuration: configuration)
        guard point.x >= calendarX else { return nil }
        let index = Int((point.x - calendarX) / dayColumnWidth(configuration: configuration))
        guard configuration.dayOrder.indices.contains(index) else { return nil }
        return configuration.dayOrder[index]
    }

    var scheduleBlockCountForTesting: Int { scheduleBlockViews.count }

    func scheduleInteractionDidEndForTesting(rebuildImmediately: Bool) {
        scheduleInteractionDidEnd(rebuildImmediately: rebuildImmediately)
    }
}
