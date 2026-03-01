import SwiftUI
import Combine

struct WeeklyCalendarView: View {
    @EnvironmentObject private var environmentAppState: AppState
    private let actionAppState: AppState?
    var appState: AppState { actionAppState ?? environmentAppState }
    @Binding var editorContext: ScheduleEditorContext?

    @State private var dragData: DragSelection?
    @State private var scheduleInteraction: ScheduleInteraction?
    @State private var weekOffset: Int = 0

    struct DragSelection {
        let day: Int
        let startHour: CGFloat
        var endHour: CGFloat
    }

    struct DragPreviewMetrics {
        let columnWidth: CGFloat
        let startHour: CGFloat
        let endHour: CGFloat
        let yOffset: CGFloat
        let height: CGFloat
        let columnIndex: Int
    }

    struct SchedulePlacement: Identifiable {
        let id: String
        let day: Int
        let startDate: Date
        let endDate: Date
    }

    struct PositionedSchedule: Identifiable {
        let id: String
        let schedule: Schedule
        let placement: SchedulePlacement
        let laneIndex: Int
        let laneCount: Int
    }

    enum ScheduleInteractionMode {
        case move
        case resizeStart
        case resizeEnd
    }

    struct ScheduleInteraction {
        let placementId: String
        let schedule: Schedule
        let originalDay: Int
        let mode: ScheduleInteractionMode
        var translation: CGSize = .zero
    }

    init(
        editorContext: Binding<ScheduleEditorContext?>,
        actionAppState: AppState? = nil,
        initialWeekOffset: Int = 0,
        initialDragData: DragSelection? = nil
    ) {
        self._editorContext = editorContext
        self.actionAppState = actionAppState
        _weekOffset = State(initialValue: initialWeekOffset)
        _dragData = State(initialValue: initialDragData)
    }

    let hourHeight: CGFloat = 80
    let dayHeaderHeight: CGFloat = 40
    let timeLabelWidth: CGFloat = 50
    let timeColumnGutter: CGFloat = 10

    var dayOrder: [Int] {
        WeeklyCalendarView.getDayOrder(weekStartsOnMonday: appState.weekStartsOnMonday)
    }

    static func getDayOrder(weekStartsOnMonday: Bool) -> [Int] {
        if weekStartsOnMonday {
            return [2, 3, 4, 5, 6, 7, 1]  // Mon -> Sun
        } else {
            return [1, 2, 3, 4, 5, 6, 7]  // Sun -> Sat
        }
    }

    var currentWeekDates: [Date] {
        WeeklyCalendarView.getWeekDates(
            at: Date(), weekStartsOnMonday: appState.weekStartsOnMonday, offset: weekOffset)
    }

    var shouldShowExternalCalendarOverlay: Bool {
        appState.calendarIntegrationEnabled && !appState.calendarImportsBlockTime
    }

    static func getWeekDates(at date: Date = Date(), weekStartsOnMonday: Bool, offset: Int = 0)
        -> [Date]
    {
        WeekDateCalculator.getWeekDates(
            at: date, weekStartsOnMonday: weekStartsOnMonday, offset: offset)
    }

    var body: some View {
        GeometryReader { geometry in
            let calendar = Calendar.current
            let weekRange = currentWeekDates
            let (weekStart, weekEnd) = Self.weekBounds(for: weekRange, calendar: calendar)

            VStack(spacing: 0) {
                // Toolbar (Navigation)
                HStack {
                    Text(monthYearString(for: weekStart))
                        .font(.title3.bold())

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: goToPreviousWeek) {
                            Image(systemName: "chevron.left")
                                .padding(6)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }.buttonStyle(.plain)

                        Button("Today", action: goToCurrentWeek)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: goToNextWeek) {
                            Image(systemName: "chevron.right")
                                .padding(6)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                HStack(alignment: .center, spacing: 0) {
                    Text("")
                        .frame(width: timeLabelWidth + timeColumnGutter)

                    ForEach(dayOrder, id: \.self) { day in
                        VStack(spacing: 4) {
                            Text(dayName(for: day))
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            if let date = dateFor(weekday: day, in: weekRange) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.title3.bold())
                                    .foregroundColor(isToday(date: date) ? .white : .primary)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        isToday(date: date)
                                            ? FocusColor.color(for: appState.accentColorIndex)
                                            : Color.clear
                                    )
                                    .clipShape(Circle())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) {
                                ForEach(0..<24, id: \.self) { hour in
                                    ZStack(alignment: .top) {
                                        Divider()
                                        HStack(alignment: .top, spacing: 0) {
                                            Text(timeString(hour: hour))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .frame(width: timeLabelWidth, alignment: .trailing)
                                                .padding(.trailing, 8)
                                                .offset(y: -6)
                                            Spacer()
                                        }
                                    }
                                    .frame(height: hourHeight, alignment: .top)
                                    .id(hour)
                                }
                            }

                            HStack(spacing: 0) {
                                Spacer().frame(width: timeLabelWidth + timeColumnGutter)
                                ForEach(0..<7, id: \.self) { _ in
                                    Spacer()
                                    Divider()
                                }
                            }

                            HStack(spacing: 0) {
                                Spacer().frame(width: timeLabelWidth + timeColumnGutter)
                                ForEach(0..<7, id: \.self) { columnIndex in
                                    let day = dayOrder[columnIndex]
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .frame(maxWidth: .infinity, maxHeight: 24 * hourHeight)
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged(dragChangedAction(day: day))
                                                .onEnded(dragEndedAction(day: day))
                                        )
                                }
                            }

                            if let data = dragData,
                                let metrics = dragPreviewMetrics(
                                    data: data,
                                    geometryWidth: geometry.size.width
                                )
                            {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            FocusColor.color(for: appState.accentColorIndex)
                                                .opacity(0.3)
                                        )
                                        .overlay(
                                            VStack {
                                                Text(
                                                    "\(formatTime(metrics.startHour)) - \(formatTime(metrics.endHour))"
                                                )
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(
                                                        FocusColor.color(
                                                            for: appState.accentColorIndex)
                                                    )
                                                    .padding(4)
                                                    .background(
                                                        Color(NSColor.windowBackgroundColor)
                                                            .opacity(0.8)
                                                    )
                                                    .cornerRadius(4)
                                                    .offset(y: -25)
                                            },
                                            alignment: .top
                                        )
                                        .frame(width: metrics.columnWidth - 4, height: metrics.height)
                                        .offset(
                                            x: timeLabelWidth + timeColumnGutter
                                                + CGFloat(metrics.columnIndex) * metrics.columnWidth + 2,
                                            y: metrics.yOffset
                                        )
                            }

                            HStack(spacing: 0) {
                                Spacer().frame(width: timeLabelWidth + timeColumnGutter)
                                GeometryReader { innerGeo in
                                    let columnWidth = innerGeo.size.width / 7

                                    ZStack(alignment: .topLeading) {
                                        if shouldShowExternalCalendarOverlay {
                                            ForEach(visibleCalendarEvents(weekStart: weekStart, weekEnd: weekEnd))
                                            { event in
                                                let weekday = calendar.component(
                                                    .weekday, from: event.startDate)
                                                if let colIndex = dayOrder.firstIndex(of: weekday),
                                                    let frame = calculateRect(
                                                        startDate: event.startDate,
                                                        endDate: event.endDate, colIndex: colIndex,
                                                        columnWidth: columnWidth)
                                                {
                                                    ExternalEventBlockView(event: event)
                                                        .frame(
                                                            width: frame.width, height: frame.height
                                                        )
                                                        .position(x: frame.midX, y: frame.midY)
                                                }
                                            }
                                        }

                                        ForEach(positionedSchedules(weekRange: weekRange)) { entry in
                                            if let colIndex = dayOrder.firstIndex(of: entry.placement.day),
                                                let baseFrame = Self.calculateRect(
                                                    startDate: entry.placement.startDate,
                                                    endDate: entry.placement.endDate,
                                                    colIndex: colIndex,
                                                    columnWidth: columnWidth,
                                                    laneIndex: entry.laneIndex,
                                                    laneCount: entry.laneCount,
                                                    hourHeight: hourHeight
                                                )
                                            {
                                                let frame = previewFrame(
                                                    for: entry,
                                                    baseFrame: baseFrame
                                                )

                                                if Self.canDirectlyManipulate(entry.schedule) {
                                                    interactiveScheduleBlock(
                                                        entry: entry,
                                                        frame: frame,
                                                        columnWidth: columnWidth,
                                                        weekRange: weekRange
                                                    )
                                                } else {
                                                    ScheduleBlockView(schedule: entry.schedule)
                                                        .frame(
                                                            width: frame.width, height: frame.height
                                                        )
                                                        .position(x: frame.midX, y: frame.midY)
                                                        .onTapGesture(
                                                            perform: openScheduleEditorAction(
                                                                day: entry.placement.day,
                                                                schedule: entry.schedule
                                                            )
                                                        )
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            CurrentTimeIndicator(
                                hourHeight: hourHeight,
                                timeLabelWidth: timeLabelWidth + timeColumnGutter,
                                dayOrder: dayOrder,
                                weekStart: weekStart,
                                weekEnd: weekEnd
                            )
                        }
                    }
                    .onAppear {
                        scrollToCurrentTime(proxy: proxy)
                    }
                }
            }
        }
    }

    private func scrollToCurrentTime(proxy: ScrollViewProxy) {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let targetHour = max(0, currentHour - 2)
        proxy.scrollTo(targetHour, anchor: .top)
    }

    func goToPreviousWeek() {
        weekOffset -= 1
    }

    func goToCurrentWeek() {
        weekOffset = 0
    }

    func goToNextWeek() {
        weekOffset += 1
    }

    func handleDragChanged(day: Int, startY: CGFloat, currentY: CGFloat) {
        if abs(currentY - startY) > 5 {
            if dragData == nil {
                dragData = DragSelection(
                    day: day,
                    startHour: startY / hourHeight,
                    endHour: currentY / hourHeight
                )
            } else {
                dragData?.endHour = currentY / hourHeight
            }
        }
    }

    func handleDragEnded(day: Int, startY: CGFloat) {
        if let data = dragData {
            finalizeDrag(data)
            dragData = nil
        } else {
            let hour = Int(startY / hourHeight)
            quickAdd(day: day, hour: hour)
        }
    }

    func dragChangedAction(day: Int) -> (DragGesture.Value) -> Void {
        { value in
            handleDragChanged(
                day: day,
                startY: value.startLocation.y,
                currentY: value.location.y
            )
        }
    }

    func dragEndedAction(day: Int) -> (DragGesture.Value) -> Void {
        { value in
            handleDragEnded(
                day: day,
                startY: value.startLocation.y
            )
        }
    }

    func dragPreviewMetrics(data: DragSelection, geometryWidth: CGFloat) -> DragPreviewMetrics? {
        WeeklyCalendarView.dragPreviewMetrics(
            data: data,
            dayOrder: dayOrder,
            geometryWidth: geometryWidth,
            timeLabelWidth: timeLabelWidth,
            timeColumnGutter: timeColumnGutter,
            hourHeight: hourHeight
        )
    }

    static func dragPreviewMetrics(
        data: DragSelection,
        dayOrder: [Int],
        geometryWidth: CGFloat,
        timeLabelWidth: CGFloat,
        timeColumnGutter: CGFloat,
        hourHeight: CGFloat
    ) -> DragPreviewMetrics? {
        let columnWidth = (geometryWidth - (timeLabelWidth + timeColumnGutter)) / 7
        let snap = { (h: CGFloat) -> CGFloat in
            (h * 4).rounded() / 4.0
        }

        let startH = snap(min(data.startHour, data.endHour))
        let endH = snap(max(data.startHour, data.endHour))
        let y = startH * hourHeight
        let h = max(endH - startH, 0.25) * hourHeight

        guard let colIndex = dayOrder.firstIndex(of: data.day) else {
            return nil
        }

        return DragPreviewMetrics(
            columnWidth: columnWidth,
            startHour: startH,
            endHour: endH,
            yOffset: y,
            height: h,
            columnIndex: colIndex
        )
    }

    func formatTime(_ h: CGFloat) -> String {
        WeeklyCalendarView.formatTime(h)
    }

    static func formatTime(_ h: CGFloat) -> String {
        let hour = Int(h)
        let min = Int(((h - CGFloat(hour)) * 60).rounded())
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: min))!
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func quickAdd(day: Int, hour: Int) {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: hour, minute: 0))
        let end = calendar.date(from: DateComponents(hour: hour + 1, minute: 0))

        editorContext = ScheduleEditorContext(
            day: day,
            startTime: start,
            endTime: end,
            schedule: nil,
            weekOffset: weekOffset
        )
    }

    func finalizeDrag(_ data: DragSelection) {
        let result = WeeklyCalendarView.calculateDragSelection(
            startHour: data.startHour,
            endHour: data.endHour
        )

        editorContext = ScheduleEditorContext(
            day: data.day,
            startTime: result.start,
            endTime: result.end,
            schedule: nil,
            weekOffset: weekOffset
        )
    }

    func visibleCalendarEvents(weekStart: Date, weekEnd: Date) -> [ExternalEvent] {
        appState.calendarProvider.events.filter {
            $0.startDate >= weekStart && $0.startDate < weekEnd
        }
    }

    func shouldDisplaySchedule(_ schedule: Schedule, weekStart: Date, weekEnd: Date) -> Bool {
        let calendar = Calendar.current
        if let specificDate = schedule.date {
            let d = calendar.startOfDay(for: specificDate)
            let s = calendar.startOfDay(for: weekStart)
            let e = calendar.startOfDay(for: weekEnd)
            return d >= s && d < e
        }
        return true
    }

    func openScheduleEditor(day: Int, schedule: Schedule) {
        editorContext = ScheduleEditorContext(
            day: day,
            schedule: schedule,
            weekOffset: weekOffset
        )
    }

    func openScheduleEditorAction(day: Int, schedule: Schedule) -> () -> Void {
        { openScheduleEditor(day: day, schedule: schedule) }
    }

    @ViewBuilder
    private func interactiveScheduleBlock(
        entry: PositionedSchedule,
        frame: CGRect,
        columnWidth: CGFloat,
        weekRange: [Date]
    ) -> some View {
        ScheduleBlockView(schedule: entry.schedule)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .overlay(alignment: .top) {
                resizeHandle
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged(
                                scheduleInteractionChangedAction(
                                    entry: entry,
                                    mode: .resizeStart,
                                    columnWidth: columnWidth
                                )
                            )
                            .onEnded(
                                scheduleInteractionEndedAction(
                                    entry: entry,
                                    mode: .resizeStart,
                                    columnWidth: columnWidth,
                                    weekRange: weekRange
                                )
                            )
                    )
            }
            .overlay(alignment: .bottom) {
                resizeHandle
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged(
                                scheduleInteractionChangedAction(
                                    entry: entry,
                                    mode: .resizeEnd,
                                    columnWidth: columnWidth
                                )
                            )
                            .onEnded(
                                scheduleInteractionEndedAction(
                                    entry: entry,
                                    mode: .resizeEnd,
                                    columnWidth: columnWidth,
                                    weekRange: weekRange
                                )
                            )
                    )
            }
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged(
                        scheduleInteractionChangedAction(
                            entry: entry,
                            mode: .move,
                            columnWidth: columnWidth
                        )
                    )
                    .onEnded(
                        scheduleInteractionEndedAction(
                            entry: entry,
                            mode: .move,
                            columnWidth: columnWidth,
                            weekRange: weekRange
                        )
                    )
            )
            .onTapGesture(
                perform: openScheduleEditorAction(
                    day: entry.placement.day,
                    schedule: entry.schedule
                )
            )
    }

    private var resizeHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.95))
            .frame(width: 28, height: 4)
            .padding(.vertical, 4)
            .shadow(color: Color.black.opacity(0.15), radius: 1, y: 1)
    }

    private func previewFrame(for entry: PositionedSchedule, baseFrame: CGRect) -> CGRect {
        guard let scheduleInteraction, scheduleInteraction.placementId == entry.id else {
            return baseFrame
        }
        return Self.previewFrame(
            baseFrame: baseFrame,
            translation: scheduleInteraction.translation,
            mode: scheduleInteraction.mode
        )
    }

    func scheduleInteractionChangedAction(
        entry: PositionedSchedule,
        mode: ScheduleInteractionMode,
        columnWidth: CGFloat
    ) -> (DragGesture.Value) -> Void {
        { value in
            scheduleInteraction = ScheduleInteraction(
                placementId: entry.id,
                schedule: entry.schedule,
                originalDay: entry.placement.day,
                mode: mode,
                translation: Self.snappedInteractionTranslation(
                    translation: value.translation,
                    mode: mode,
                    columnWidth: columnWidth,
                    hourHeight: hourHeight
                )
            )
        }
    }

    func scheduleInteractionEndedAction(
        entry: PositionedSchedule,
        mode: ScheduleInteractionMode,
        columnWidth: CGFloat,
        weekRange: [Date]
    ) -> (DragGesture.Value) -> Void {
        { value in
            let update = Self.scheduleUpdate(
                placement: entry.placement,
                translation: value.translation,
                mode: mode,
                columnWidth: columnWidth,
                hourHeight: hourHeight,
                weekRange: weekRange
            )
            scheduleInteraction = nil
            guard let update else { return }
            appState.updateScheduleOccurrence(
                id: entry.schedule.id,
                originalDay: entry.placement.day,
                targetDay: update.targetDay,
                targetDate: update.targetDate,
                start: update.start,
                end: update.end
            )
        }
    }

    func schedulePlacements(for schedule: Schedule, weekRange: [Date]) -> [SchedulePlacement] {
        let calendar = Calendar.current

        if let specificDate = schedule.date {
            guard let inWeekDate = weekRange.first(where: { calendar.isDate($0, inSameDayAs: specificDate) }) else {
                return []
            }
            let day = calendar.component(.weekday, from: inWeekDate)
            let startOfDay = calendar.startOfDay(for: inWeekDate).timeIntervalSince1970
            return [
                SchedulePlacement(
                    id: "\(schedule.id.uuidString)-\(startOfDay)",
                    day: day,
                    startDate: schedule.startTime,
                    endDate: schedule.endTime
                )
            ]
        }

        return schedule.days.sorted().map { day in
            SchedulePlacement(
                id: "\(schedule.id.uuidString)-\(day)",
                day: day,
                startDate: schedule.startTime,
                endDate: schedule.endTime
            )
        }
    }

    func positionedSchedules(weekRange: [Date]) -> [PositionedSchedule] {
        let visible = appState.schedules.filter {
            let bounds = Self.weekBounds(for: weekRange)
            return shouldDisplaySchedule($0, weekStart: bounds.0, weekEnd: bounds.1)
        }
        let placements = visible.flatMap { schedule in
            schedulePlacements(for: schedule, weekRange: weekRange).map {
                (schedule: schedule, placement: $0)
            }
        }
        return Self.positionedSchedules(from: placements)
    }

    static func positionedSchedules(
        from placements: [(schedule: Schedule, placement: SchedulePlacement)],
        calendar: Calendar = .current
    ) -> [PositionedSchedule] {
        Dictionary(grouping: placements, by: { $0.placement.day })
            .values
            .flatMap { dayPlacements in
                let sorted = dayPlacements.sorted {
                    let lhs = normalizedInterval(for: $0.placement, calendar: calendar)
                    let rhs = normalizedInterval(for: $1.placement, calendar: calendar)
                    if lhs.start != rhs.start { return lhs.start < rhs.start }
                    if lhs.end != rhs.end { return lhs.end < rhs.end }
                    return $0.placement.id < $1.placement.id
                }

                var laneAssignments: [String: Int] = [:]
                var laneEnds: [Date] = []

                for entry in sorted {
                    let interval = normalizedInterval(for: entry.placement, calendar: calendar)
                    var laneIndex = 0
                    while laneIndex < laneEnds.count && laneEnds[laneIndex] > interval.start {
                        laneIndex += 1
                    }
                    if laneIndex < laneEnds.count {
                        laneEnds[laneIndex] = interval.end
                    } else {
                        laneEnds.append(interval.end)
                    }
                    laneAssignments[entry.placement.id] = laneIndex
                }

                return sorted.map { entry in
                    PositionedSchedule(
                        id: entry.placement.id,
                        schedule: entry.schedule,
                        placement: entry.placement,
                        laneIndex: laneAssignments[entry.placement.id] ?? 0,
                        laneCount: max(
                            1,
                            concurrentLaneCount(
                                for: entry.placement,
                                among: sorted.map(\.placement),
                                calendar: calendar
                            )
                        )
                    )
                }
            }
            .sorted { lhs, rhs in
                if lhs.placement.day != rhs.placement.day { return lhs.placement.day < rhs.placement.day }
                let lhsInterval = normalizedInterval(for: lhs.placement, calendar: calendar)
                let rhsInterval = normalizedInterval(for: rhs.placement, calendar: calendar)
                if lhsInterval.start != rhsInterval.start { return lhsInterval.start < rhsInterval.start }
                if lhs.laneIndex != rhs.laneIndex { return lhs.laneIndex < rhs.laneIndex }
                return lhs.id < rhs.id
            }
    }

    static func calculateDragSelection(startHour: CGFloat, endHour: CGFloat) -> (
        start: Date, end: Date
    ) {
        let calendar = Calendar.current
        let snap = { (h: CGFloat) -> CGFloat in
            return (h * 4).rounded() / 4.0
        }

        let sH = snap(min(startHour, endHour))
        var eH = snap(max(startHour, endHour))

        if eH - sH < 0.25 {
            eH = sH + 0.25
        }

        let sHour = Int(sH)
        let sMin = Int(((sH - CGFloat(sHour)) * 60).rounded())

        let eHour = Int(eH)
        let eMin = Int(((eH - CGFloat(eHour)) * 60).rounded())

        let start = calendar.date(from: DateComponents(hour: sHour, minute: sMin))!
        let end = calendar.date(from: DateComponents(hour: eHour, minute: eMin))!

        return (start, end)
    }

    struct ScheduleUpdate {
        let targetDay: Int
        let targetDate: Date?
        let start: Date
        let end: Date
    }

    static func previewFrame(
        baseFrame: CGRect,
        translation: CGSize,
        mode: ScheduleInteractionMode,
        minimumHeight: CGFloat = 15
    ) -> CGRect {
        switch mode {
        case .move:
            return baseFrame.offsetBy(dx: translation.width, dy: translation.height)
        case .resizeStart:
            let clampedDelta = min(translation.height, baseFrame.height - minimumHeight)
            return CGRect(
                x: baseFrame.minX,
                y: baseFrame.minY + clampedDelta,
                width: baseFrame.width,
                height: baseFrame.height - clampedDelta
            )
        case .resizeEnd:
            return CGRect(
                x: baseFrame.minX,
                y: baseFrame.minY,
                width: baseFrame.width,
                height: max(baseFrame.height + translation.height, minimumHeight)
            )
        }
    }

    static func snappedInteractionTranslation(
        translation: CGSize,
        mode: ScheduleInteractionMode,
        columnWidth: CGFloat,
        hourHeight: CGFloat
    ) -> CGSize {
        let snappedY = CGFloat(
            snappedMinuteDelta(
                translationHeight: translation.height,
                hourHeight: hourHeight
            )
        ) * hourHeight / 60

        switch mode {
        case .move:
            let snappedX = CGFloat(
                snappedDayDelta(
                    translationWidth: translation.width,
                    columnWidth: columnWidth
                )
            ) * columnWidth
            return CGSize(width: snappedX, height: snappedY)
        case .resizeStart, .resizeEnd:
            return CGSize(width: 0, height: snappedY)
        }
    }

    static func scheduleUpdate(
        placement: SchedulePlacement,
        translation: CGSize,
        mode: ScheduleInteractionMode,
        columnWidth: CGFloat,
        hourHeight: CGFloat,
        weekRange: [Date],
        calendar: Calendar = .current
    ) -> ScheduleUpdate? {
        let dayDelta = mode == .move ? snappedDayDelta(translationWidth: translation.width, columnWidth: columnWidth) : 0
        let minuteDelta = snappedMinuteDelta(translationHeight: translation.height, hourHeight: hourHeight)
        let targetDay = shiftedWeekday(placement.day, by: dayDelta)
        let adjustedTimes = adjustedTimes(
            start: placement.startDate,
            end: placement.endDate,
            minuteDelta: minuteDelta,
            mode: mode,
            calendar: calendar
        )

        let targetDate = weekRange.first {
            calendar.component(.weekday, from: $0) == targetDay
        }

        return ScheduleUpdate(
            targetDay: targetDay,
            targetDate: targetDate,
            start: adjustedTimes.start,
            end: adjustedTimes.end
        )
    }

    static func snappedMinuteDelta(translationHeight: CGFloat, hourHeight: CGFloat) -> Int {
        Int((translationHeight / hourHeight * 4).rounded()) * 15
    }

    static func snappedDayDelta(translationWidth: CGFloat, columnWidth: CGFloat) -> Int {
        Int((translationWidth / columnWidth).rounded())
    }

    static func shiftedWeekday(_ weekday: Int, by delta: Int) -> Int {
        let zeroBased = weekday - 1
        return ((zeroBased + delta) % 7 + 7) % 7 + 1
    }

    static func adjustedTimes(
        start: Date,
        end: Date,
        minuteDelta: Int,
        mode: ScheduleInteractionMode,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let interval = normalizedInterval(
            startDate: start,
            endDate: end,
            calendar: calendar
        )
        let delta = TimeInterval(minuteDelta * 60)
        let minimumDuration: TimeInterval = 15 * 60

        let updatedInterval: DateInterval
        switch mode {
        case .move:
            updatedInterval = DateInterval(
                start: interval.start.addingTimeInterval(delta),
                end: interval.end.addingTimeInterval(delta)
            )
        case .resizeStart:
            let newStart = min(interval.start.addingTimeInterval(delta), interval.end.addingTimeInterval(-minimumDuration))
            updatedInterval = DateInterval(start: newStart, end: interval.end)
        case .resizeEnd:
            let newEnd = max(interval.end.addingTimeInterval(delta), interval.start.addingTimeInterval(minimumDuration))
            updatedInterval = DateInterval(start: interval.start, end: newEnd)
        }

        return (
            timeOnlyDate(from: updatedInterval.start, calendar: calendar),
            timeOnlyDate(from: updatedInterval.end, calendar: calendar)
        )
    }

    static func canDirectlyManipulate(_ schedule: Schedule) -> Bool {
        schedule.importedCalendarEventKey == nil
    }

    func dayName(for day: Int) -> String {
        WeeklyCalendarView.dayName(for: day)
    }

    static func dayName(for day: Int) -> String {
        return Calendar.current.shortWeekdaySymbols[day - 1]
    }

    func isToday(day: Int) -> Bool {
        return Calendar.current.component(.weekday, from: Date()) == day
    }

    func timeString(hour: Int) -> String {
        WeeklyCalendarView.timeString(hour: hour)
    }

    static func timeString(hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(from: DateComponents(hour: hour))!
        return formatter.string(from: date)
    }

    static func weekBounds(for weekRange: [Date], calendar: Calendar = .current) -> (Date, Date) {
        guard let weekStart = weekRange.first, let weekLast = weekRange.last else {
            return (.distantPast, .distantFuture)
        }

        let weekEnd = calendar.date(byAdding: .day, value: 1, to: weekLast)!
        return (weekStart, weekEnd)
    }

    private func monthYearString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private func dateFor(weekday: Int, in range: [Date]) -> Date? {
        range.first { Calendar.current.component(.weekday, from: $0) == weekday }
    }

    private func isToday(date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func calculateRect(startDate: Date, endDate: Date, colIndex: Int, columnWidth: CGFloat)
        -> CGRect?
    {
        WeeklyCalendarView.calculateRect(
            startDate: startDate,
            endDate: endDate,
            colIndex: colIndex,
            columnWidth: columnWidth,
            laneIndex: 0,
            laneCount: 1,
            hourHeight: hourHeight
        )
    }

    static func calculateRect(
        startDate: Date,
        endDate: Date,
        colIndex: Int,
        columnWidth: CGFloat,
        laneIndex: Int = 0,
        laneCount: Int = 1,
        hourHeight: CGFloat
    ) -> CGRect? {
        let calendar = Calendar.current
        let startComp = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComp = calendar.dateComponents([.hour, .minute], from: endDate)

        let startHour = startComp.hour!
        let startMin = startComp.minute!
        let endHour = endComp.hour!
        let endMin = endComp.minute!

        let startY = (CGFloat(startHour) + CGFloat(startMin) / 60.0) * hourHeight
        var endY = (CGFloat(endHour) + CGFloat(endMin) / 60.0) * hourHeight

        if startY >= endY { endY = 24 * hourHeight }

        let height = max(endY - startY, 15)
        let horizontalPadding: CGFloat = 2
        let usableWidth = max(columnWidth - horizontalPadding * 2, 1)
        let clampedLaneCount = max(laneCount, 1)
        let laneWidth = usableWidth / CGFloat(clampedLaneCount)
        let laneX = CGFloat(min(max(laneIndex, 0), clampedLaneCount - 1)) * laneWidth
        let x = CGFloat(colIndex) * columnWidth + horizontalPadding + laneX

        return CGRect(x: x, y: startY, width: laneWidth, height: height)
    }

    var weekOffsetForTesting: Int { weekOffset }
    var dragDataForTesting: DragSelection? { dragData }

    private static func normalizedInterval(
        for placement: SchedulePlacement,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let interval = normalizedInterval(
            startDate: placement.startDate,
            endDate: placement.endDate,
            calendar: calendar
        )
        return (interval.start, interval.end)
    }

    private static func normalizedInterval(
        startDate: Date,
        endDate: Date,
        calendar: Calendar
    ) -> DateInterval {
        let anchor = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        let start = calendar.date(
            bySettingHour: startComponents.hour ?? 0,
            minute: startComponents.minute ?? 0,
            second: 0,
            of: anchor
        ) ?? anchor
        var end = calendar.date(
            bySettingHour: endComponents.hour ?? 0,
            minute: endComponents.minute ?? 0,
            second: 0,
            of: anchor
        ) ?? anchor
        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return DateInterval(start: start, end: end)
    }

    private static func timeOnlyDate(from date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return calendar.date(
            from: DateComponents(hour: components.hour, minute: components.minute)
        ) ?? date
    }

    private static func concurrentLaneCount(
        for target: SchedulePlacement,
        among placements: [SchedulePlacement],
        calendar: Calendar
    ) -> Int {
        let targetInterval = normalizedInterval(for: target, calendar: calendar)
        let candidateStarts = placements.map { normalizedInterval(for: $0, calendar: calendar).start }
        let candidateEnds = placements.map { normalizedInterval(for: $0, calendar: calendar).end }
        let checkpoints = Set(candidateStarts + candidateEnds)
            .filter { $0 >= targetInterval.start && $0 < targetInterval.end }

        var maxConcurrent = 1
        for checkpoint in checkpoints {
            let concurrent = placements.reduce(into: 0) { count, placement in
                let interval = normalizedInterval(for: placement, calendar: calendar)
                if interval.start <= checkpoint && checkpoint < interval.end {
                    count += 1
                }
            }
            maxConcurrent = max(maxConcurrent, concurrent)
        }
        return maxConcurrent
    }
}

struct ExternalEventBlockView: View {
    let event: ExternalEvent

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(.secondary.opacity(0.4))
            )
            .overlay(
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(event.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    Spacer()
                }
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            )
    }
}

struct ScheduleBlockView: View {
    let schedule: Schedule

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(blockFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(blockBorderColor, lineWidth: 1)
            )
            .overlay(
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(
                            systemName: schedule.type == .focus ? "target" : "cup.and.saucer.fill"
                        )
                        .font(.system(size: 10, weight: .bold))
                        Text(schedule.name)
                            .font(.caption)
                            .bold()
                        if isImported {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .lineLimit(1)

                    Text(timeRange(schedule))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            )
    }

    var blockFillColor: Color {
        if !schedule.isEnabled {
            return Color.gray.opacity(0.5)
        }
        return schedule.themeColor.opacity(Self.fillOpacity(isImported: isImported))
    }

    var blockBorderColor: Color {
        if !schedule.isEnabled {
            return Color.gray.opacity(0.8)
        }
        return schedule.themeColor.opacity(Self.borderOpacity(isImported: isImported))
    }

    static func fillOpacity(isImported: Bool) -> Double {
        isImported ? 0.5 : 0.8
    }

    static func borderOpacity(isImported: Bool) -> Double {
        isImported ? 0.72 : 0.95
    }

    func timeRange(_ s: Schedule) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: s.startTime))"
    }

    var isImported: Bool {
        schedule.importedCalendarEventKey != nil
    }
}

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    let timeLabelWidth: CGFloat
    let dayOrder: [Int]
    let weekStart: Date
    let weekEnd: Date

    @State private var currentTimeOffset: CGFloat
    @State private var currentDayIndex: Int?
    let timer: Publishers.Autoconnect<Timer.TimerPublisher>

    init(
        hourHeight: CGFloat,
        timeLabelWidth: CGFloat,
        dayOrder: [Int],
        weekStart: Date,
        weekEnd: Date,
        initialCurrentTimeOffset: CGFloat = 0,
        initialCurrentDayIndex: Int? = nil,
        timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(
            every: 60, on: .main, in: .common
        ).autoconnect()
    ) {
        self.hourHeight = hourHeight
        self.timeLabelWidth = timeLabelWidth
        self.dayOrder = dayOrder
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.timer = timer
        _currentTimeOffset = State(initialValue: initialCurrentTimeOffset)
        _currentDayIndex = State(initialValue: initialCurrentDayIndex)
    }

    var body: some View {
        Group {
            let now = Date()
            if now >= weekStart && now < weekEnd {
                GeometryReader { geo in
                    if let colIndex = currentDayIndex {
                        let columnWidth = (geo.size.width - timeLabelWidth) / 7
                        let xOffset = timeLabelWidth + CGFloat(colIndex) * columnWidth

                        HStack(spacing: 0) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: xOffset - 4)

                            Rectangle()
                                .fill(Color.red)
                                .frame(width: columnWidth, height: 1)
                                .offset(x: xOffset - 4)
                        }
                        .offset(y: currentTimeOffset)
                    }
                }
            }
        }
        .onAppear { updateTime() }
        .onReceive(timer, perform: onTimerTick)
    }

    func onTimerTick(_: Date) {
        updateTime()
    }

    func updateTime() {
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        if let h = comps.hour, let m = comps.minute, let w = comps.weekday {
            currentTimeOffset = (CGFloat(h) + CGFloat(m) / 60.0) * hourHeight
            currentDayIndex = dayOrder.firstIndex(of: w)
        }
    }
}
