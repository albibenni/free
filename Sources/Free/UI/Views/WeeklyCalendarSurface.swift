import AppKit

struct WeeklyCalendarSurfaceConfiguration {
    let dayOrder: [Int]
    let weekRange: [Date]
    let weekStart: Date
    let weekEnd: Date
    let positionedSchedules: [WeeklyCalendarSupport.PositionedSchedule]
    let externalEvents: [ExternalEvent]
    let showsExternalEvents: Bool
    let hourHeight: CGFloat
    let dayHeaderHeight: CGFloat
    let timeLabelWidth: CGFloat
    let timeColumnGutter: CGFloat
    let accentColor: NSColor
    let onQuickAdd: (Int, Int) -> Void
    let onCreateSelection: (Int, CGFloat, CGFloat) -> Void
    let onOpenSchedule: (Int, Schedule) -> Void
    let onUpdateSchedule: (UUID, Int, Int, Date?, Date, Date) -> Void
}

final class WeeklyCalendarSurfaceNSView: NSView {
    private let headerView = WeeklyCalendarSurfaceHeaderNSView()
    private let scrollView = NSScrollView()
    private let documentView = WeeklyCalendarSurfaceDocumentNSView()
    private var configuration: WeeklyCalendarSurfaceConfiguration?
    private var didInitialScroll = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.masksToBounds = true

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = documentView

        addSubview(headerView)
        addSubview(scrollView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with configuration: WeeklyCalendarSurfaceConfiguration) {
        self.configuration = configuration
        headerView.configure(
            dayOrder: configuration.dayOrder,
            weekRange: configuration.weekRange,
            accentColor: configuration.accentColor,
            timeLabelWidth: configuration.timeLabelWidth,
            timeColumnGutter: configuration.timeColumnGutter
        )
        documentView.configure(with: configuration)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard let configuration else { return }

        let headerHeight = max(configuration.dayHeaderHeight + 20, 56)
        headerView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: headerHeight)
        scrollView.frame = CGRect(
            x: 0,
            y: headerHeight,
            width: bounds.width,
            height: max(bounds.height - headerHeight, 0)
        )

        let contentWidth = max(
            scrollView.contentSize.width,
            configuration.timeLabelWidth + configuration.timeColumnGutter + 7
        )
        let contentHeight = 24 * configuration.hourHeight
        let documentFrame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        let needsDocumentLayout = documentView.frame.size != documentFrame.size
        documentView.frame = documentFrame
        if needsDocumentLayout {
            documentView.applyCurrentLayout()
        }

        if !didInitialScroll {
            scrollToCurrentTime(hourHeight: configuration.hourHeight)
            didInitialScroll = true
        }
    }

    private func scrollToCurrentTime(hourHeight: CGFloat) {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let targetHour = max(0, currentHour - 2)
        let point = CGPoint(x: 0, y: CGFloat(targetHour) * hourHeight)
        scrollView.contentView.scroll(to: point)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

private final class WeeklyCalendarSurfaceHeaderNSView: NSView {
    private var dayOrder: [Int] = []
    private var weekRange: [Date] = []
    private var accentColor: NSColor = .controlAccentColor
    private var timeLabelWidth: CGFloat = 50
    private var timeColumnGutter: CGFloat = 10

    override var isFlipped: Bool { true }

    func configure(
        dayOrder: [Int],
        weekRange: [Date],
        accentColor: NSColor,
        timeLabelWidth: CGFloat,
        timeColumnGutter: CGFloat
    ) {
        self.dayOrder = dayOrder
        self.weekRange = weekRange
        self.accentColor = accentColor
        self.timeLabelWidth = timeLabelWidth
        self.timeColumnGutter = timeColumnGutter
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()

        let calendarX = timeLabelWidth + timeColumnGutter
        let columnWidth = max((bounds.width - calendarX) / 7, 1)
        let calendar = Calendar.current

        let weekdayAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let dayAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ]
        let todayAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: NSColor.white,
        ]

        for (index, day) in dayOrder.enumerated() {
            let columnRect = CGRect(
                x: calendarX + CGFloat(index) * columnWidth,
                y: 0,
                width: columnWidth,
                height: bounds.height
            )

            let weekdayText = WeeklyCalendarSupport.dayName(for: day) as NSString
            let weekdaySize = weekdayText.size(withAttributes: weekdayAttributes)
            weekdayText.draw(
                at: CGPoint(
                    x: columnRect.midX - weekdaySize.width / 2,
                    y: 10
                ),
                withAttributes: weekdayAttributes
            )

            guard let date = weekRange.first(where: {
                calendar.component(.weekday, from: $0) == day
            }) else {
                continue
            }

            let dayString = "\(calendar.component(.day, from: date))" as NSString
            let isToday = calendar.isDateInToday(date)
            let badgeRect = CGRect(
                x: columnRect.midX - 14,
                y: 26,
                width: 28,
                height: 28
            )
            if isToday {
                let badgePath = NSBezierPath(ovalIn: badgeRect)
                accentColor.setFill()
                badgePath.fill()
            }

            let attributes = isToday ? todayAttributes : dayAttributes
            let daySize = dayString.size(withAttributes: attributes)
            dayString.draw(
                at: CGPoint(
                    x: badgeRect.midX - daySize.width / 2,
                    y: badgeRect.midY - daySize.height / 2
                ),
                withAttributes: attributes
            )
        }
    }
}

private final class WeeklyCalendarSurfaceDocumentNSView: NSView {
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
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    func configure(with configuration: WeeklyCalendarSurfaceConfiguration) {
        self.configuration = configuration
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
            let dashed = path.copy() as? NSBezierPath ?? path
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
        configuration.accentColor.withAlphaComponent(0.25).setFill()
        path.fill()

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

        configuration.accentColor.setFill()
        NSBezierPath(ovalIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)).fill()

        configuration.accentColor.setStroke()
        let line = NSBezierPath()
        line.lineWidth = 1
        line.move(to: CGPoint(x: x, y: y))
        line.line(to: CGPoint(x: x + width, y: y))
        line.stroke()
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
}

private final class WeeklyCalendarSurfaceScheduleBlockNSView: NSView {
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
            )
            guard let update else {
                frame = originalFrame
                finishInteraction(rebuildImmediately: true)
                return
            }
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
            let baseColor = FocusColor.nsColor(for: schedule.colorIndex)
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

        if let typeIcon = symbolImage(
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
           let importedIcon = symbolImage(
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

    private func symbolImage(
        named symbolName: String,
        pointSize: CGFloat,
        weight: NSFont.Weight,
        color: NSColor
    ) -> NSImage? {
        guard
            let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        else {
            return nil
        }

        let configuredImage =
            baseImage
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: weight))?
            .withSymbolConfiguration(.init(paletteColors: [color]))

        return configuredImage ?? baseImage
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
