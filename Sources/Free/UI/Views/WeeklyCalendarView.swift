import Combine
import SwiftUI

#if canImport(AppKit)
    import AppKit
#endif

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
    let resizeHandleHitHeight: CGFloat = 18
    let toolbarHeight: CGFloat = 56

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
        let calendar = Calendar.current
        let weekRange = currentWeekDates
        let (weekStart, weekEnd) = Self.weekBounds(for: weekRange, calendar: calendar)

        ZStack(alignment: .top) {
            WeeklyCalendarAppKitView(
                dayOrder: dayOrder,
                weekRange: weekRange,
                weekStart: weekStart,
                weekEnd: weekEnd,
                positionedSchedules: positionedSchedules(weekRange: weekRange),
                externalEvents: visibleCalendarEvents(weekStart: weekStart, weekEnd: weekEnd),
                showsExternalEvents: shouldShowExternalCalendarOverlay,
                hourHeight: hourHeight,
                dayHeaderHeight: dayHeaderHeight,
                timeLabelWidth: timeLabelWidth,
                timeColumnGutter: timeColumnGutter,
                accentColor: NSColor(FocusColor.color(for: appState.accentColorIndex)),
                onQuickAdd: { day, hour in
                    quickAdd(day: day, hour: hour)
                },
                onCreateSelection: { day, startHour, endHour in
                    finalizeDrag(
                        DragSelection(day: day, startHour: startHour, endHour: endHour)
                    )
                },
                onOpenSchedule: { day, schedule in
                    openScheduleEditor(day: day, schedule: schedule)
                },
                onUpdateSchedule: { scheduleId, originalDay, targetDay, targetDate, start, end in
                    appState.updateScheduleOccurrence(
                        id: scheduleId,
                        originalDay: originalDay,
                        targetDay: targetDay,
                        targetDate: targetDate,
                        start: start,
                        end: end
                    )
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, toolbarHeight)

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
                    }
                    .buttonStyle(.plain)

                    Button("Today", action: goToCurrentWeek)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button(action: goToNextWeek) {
                        Image(systemName: "chevron.right")
                            .padding(6)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            guard
                let inWeekDate = weekRange.first(where: {
                    calendar.isDate($0, inSameDayAs: specificDate)
                })
            else {
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
                if lhs.placement.day != rhs.placement.day {
                    return lhs.placement.day < rhs.placement.day
                }
                let lhsInterval = normalizedInterval(for: lhs.placement, calendar: calendar)
                let rhsInterval = normalizedInterval(for: rhs.placement, calendar: calendar)
                if lhsInterval.start != rhsInterval.start {
                    return lhsInterval.start < rhsInterval.start
                }
                if lhs.laneIndex != rhs.laneIndex { return lhs.laneIndex < rhs.laneIndex }
                return lhs.id < rhs.id
            }
    }

    static func calculateDragSelection(startHour: CGFloat, endHour: CGFloat) -> (
        start: Date, end: Date
    ) {
        let calendar = Calendar.current
        let (sH, eH) = snappedSelectionHours(startHour: startHour, endHour: endHour)

        let sHour = Int(sH)
        let sMin = Int(((sH - CGFloat(sHour)) * 60).rounded())

        let eHour = Int(eH)
        let eMin = Int(((eH - CGFloat(eHour)) * 60).rounded())

        let start = calendar.date(from: DateComponents(hour: sHour, minute: sMin))!
        let end = calendar.date(from: DateComponents(hour: eHour, minute: eMin))!

        return (start, end)
    }

    static func selectionPreviewLabels(startHour: CGFloat, endHour: CGFloat) -> (
        start: String, end: String
    ) {
        let (snappedStart, snappedEnd) = snappedSelectionHours(
            startHour: startHour, endHour: endHour)
        return (formatTime(snappedStart), formatTime(snappedEnd))
    }

    static func snappedSelectionHours(startHour: CGFloat, endHour: CGFloat) -> (
        start: CGFloat, end: CGFloat
    ) {
        let snap = { (h: CGFloat) -> CGFloat in
            (h * 4).rounded() / 4.0
        }

        let snappedStart = snap(min(startHour, endHour))
        var snappedEnd = snap(max(startHour, endHour))

        if snappedEnd - snappedStart < 0.25 {
            snappedEnd = snappedStart + 0.25
        }

        return (snappedStart, snappedEnd)
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
        let snappedY =
            CGFloat(
                snappedMinuteDelta(
                    translationHeight: translation.height,
                    hourHeight: hourHeight
                )
            ) * hourHeight / 60

        switch mode {
        case .move:
            let snappedX =
                CGFloat(
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
        resolvedDayDelta: Int? = nil,
        calendar: Calendar = .current
    ) -> ScheduleUpdate? {
        let dayDelta =
            resolvedDayDelta
            ?? (mode == .move
                ? snappedDayDelta(translationWidth: translation.width, columnWidth: columnWidth)
                : 0)
        let minuteDelta = snappedMinuteDelta(
            translationHeight: translation.height, hourHeight: hourHeight)
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

    static func schedulePreviewLabels(
        placement: SchedulePlacement,
        translation: CGSize,
        mode: ScheduleInteractionMode,
        hourHeight: CGFloat,
        calendar: Calendar = .current
    ) -> (start: String, end: String) {
        let minuteDelta = snappedMinuteDelta(
            translationHeight: translation.height,
            hourHeight: hourHeight
        )
        let adjustedTimes = adjustedTimes(
            start: placement.startDate,
            end: placement.endDate,
            minuteDelta: minuteDelta,
            mode: mode,
            calendar: calendar
        )
        return (
            formattedTime(adjustedTimes.start, calendar: calendar),
            formattedTime(adjustedTimes.end, calendar: calendar)
        )
    }

    static func snappedMinuteDelta(translationHeight: CGFloat, hourHeight: CGFloat) -> Int {
        Int((translationHeight / hourHeight * 4).rounded()) * 15
    }

    static func snappedDayDelta(translationWidth: CGFloat, columnWidth: CGFloat) -> Int {
        Int((translationWidth / columnWidth).rounded())
    }

    static func dayDelta(
        cursorX: CGFloat,
        calendarAreaX: CGFloat,
        columnWidth: CGFloat,
        dayCount: Int,
        originalColumnIndex: Int
    ) -> Int {
        guard columnWidth > 0, dayCount > 0 else { return 0 }
        let rawIndex = Int(floor((cursorX - calendarAreaX) / columnWidth))
        let clampedIndex = min(max(rawIndex, 0), dayCount - 1)
        return clampedIndex - originalColumnIndex
    }

    static func shiftedWeekday(_ weekday: Int, by delta: Int) -> Int {
        let zeroBased = weekday - 1
        return ((zeroBased + delta) % 7 + 7) % 7 + 1
    }

    static func interactionMode(
        at point: CGPoint,
        in bounds: CGRect,
        edgeHeight: CGFloat
    ) -> ScheduleInteractionMode {
        let effectiveEdgeHeight = effectiveResizeHandleHeight(
            boundsHeight: bounds.height,
            preferredHeight: edgeHeight
        )
        if point.y <= effectiveEdgeHeight {
            return .resizeStart
        }
        if point.y >= bounds.height - effectiveEdgeHeight {
            return .resizeEnd
        }
        return .move
    }

    static func effectiveResizeHandleHeight(
        boundsHeight: CGFloat,
        preferredHeight: CGFloat,
        minimumHeight: CGFloat = 4,
        maximumHeight: CGFloat = 6
    ) -> CGFloat {
        guard boundsHeight > 0 else { return 0 }
        let cappedByHeight = max(minimumHeight, boundsHeight * 0.25)
        let cappedMaximum = min(maximumHeight, boundsHeight / 2)
        return min(max(preferredHeight, minimumHeight), min(cappedByHeight, cappedMaximum))
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
            let newStart = min(
                interval.start.addingTimeInterval(delta),
                interval.end.addingTimeInterval(-minimumDuration))
            updatedInterval = DateInterval(start: newStart, end: interval.end)
        case .resizeEnd:
            let newEnd = max(
                interval.end.addingTimeInterval(delta),
                interval.start.addingTimeInterval(minimumDuration))
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

    static func formattedTime(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeStyle = .short
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
        let start =
            calendar.date(
                bySettingHour: startComponents.hour ?? 0,
                minute: startComponents.minute ?? 0,
                second: 0,
                of: anchor
            ) ?? anchor
        var end =
            calendar.date(
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
        let candidateStarts = placements.map {
            normalizedInterval(for: $0, calendar: calendar).start
        }
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

#if canImport(AppKit)
    private struct WeeklyCalendarAppKitView: NSViewRepresentable {
        let dayOrder: [Int]
        let weekRange: [Date]
        let weekStart: Date
        let weekEnd: Date
        let positionedSchedules: [WeeklyCalendarView.PositionedSchedule]
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

        func makeNSView(context: Context) -> WeeklyCalendarContainerNSView {
            let view = WeeklyCalendarContainerNSView()
            view.configure(with: self)
            return view
        }

        func updateNSView(_ nsView: WeeklyCalendarContainerNSView, context: Context) {
            nsView.configure(with: self)
        }
    }

    private final class WeeklyCalendarContainerNSView: NSView {
        private let headerView = WeeklyCalendarHeaderNSView()
        private let scrollView = NSScrollView()
        private let documentView = WeeklyCalendarDocumentNSView()
        private var configuration: WeeklyCalendarAppKitView?
        private var didInitialScroll = false

        override var isFlipped: Bool { true }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

            scrollView.drawsBackground = false
            scrollView.borderType = .noBorder
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.documentView = documentView

            addSubview(headerView)
            addSubview(scrollView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func configure(with configuration: WeeklyCalendarAppKitView) {
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
                configuration.timeLabelWidth + configuration.timeColumnGutter + 7)
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

    private final class WeeklyCalendarHeaderNSView: NSView {
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

                let weekdayText = WeeklyCalendarView.dayName(for: day) as NSString
                let weekdaySize = weekdayText.size(withAttributes: weekdayAttributes)
                weekdayText.draw(
                    at: CGPoint(
                        x: columnRect.midX - weekdaySize.width / 2,
                        y: 10
                    ),
                    withAttributes: weekdayAttributes
                )

                guard
                    let date = weekRange.first(where: {
                        calendar.component(.weekday, from: $0) == day
                    })
                else {
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

    private final class WeeklyCalendarDocumentNSView: NSView {
        private var configuration: WeeklyCalendarAppKitView?
        private var scheduleBlockViews: [String: WeeklyCalendarScheduleBlockNSView] = [:]
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

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            timer?.invalidate()
        }

        func configure(with configuration: WeeklyCalendarAppKitView) {
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
            guard
                let configuration,
                let day = selectionDay
            else {
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
                    let frame = WeeklyCalendarView.calculateRect(
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

                let blockView = WeeklyCalendarScheduleBlockNSView()
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

        private func drawHourGrid(configuration: WeeklyCalendarAppKitView) {
            let calendarX = calendarAreaX(configuration: configuration)
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]

            for hour in 0..<24 {
                let y = CGFloat(hour) * configuration.hourHeight
                NSColor.separatorColor.setStroke()
                let line = NSBezierPath()
                line.move(to: CGPoint(x: 0, y: y))
                line.line(to: CGPoint(x: bounds.width, y: y))
                line.stroke()

                let text = WeeklyCalendarView.timeString(hour: hour) as NSString
                let textRect = CGRect(
                    x: 0,
                    y: y - 6,
                    width: configuration.timeLabelWidth,
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

        private func drawDayDividers(configuration: WeeklyCalendarAppKitView) {
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

        private func drawExternalEvents(configuration: WeeklyCalendarAppKitView) {
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
                    let frame = WeeklyCalendarView.calculateRect(
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

                let titleRect = adjustedFrame.insetBy(dx: 6, dy: 4)
                (event.title as NSString).draw(
                    in: titleRect,
                    withAttributes: titleAttributes
                )
            }
        }

        private func drawSelectionPreview(configuration: WeeklyCalendarAppKitView) {
            guard
                isSelecting,
                let day = selectionDay,
                let columnIndex = configuration.dayOrder.firstIndex(of: day)
            else {
                return
            }

            let startHour = selectionStartPoint.y / configuration.hourHeight
            let endHour = selectionCurrentPoint.y / configuration.hourHeight
            let (snappedStart, snappedEnd) = WeeklyCalendarView.snappedSelectionHours(
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

            let labels = WeeklyCalendarView.selectionPreviewLabels(
                startHour: startHour,
                endHour: endHour
            )
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.gray.withAlphaComponent(0.8),
            ]
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right
            paragraph.lineBreakMode = .byTruncatingTail
            let textAttributes = labelAttributes.merging([.paragraphStyle: paragraph]) { _, new in
                new
            }

            let startLabel = labels.start as NSString
            let endLabel = labels.end as NSString
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
            startLabel.draw(
                in: startRect,
                withAttributes: textAttributes
            )

            let endRect = CGRect(
                x: rect.minX + horizontalInset,
                y: max(rect.maxY - verticalInset - labelHeight, startRect.maxY),
                width: textWidth,
                height: labelHeight
            )
            endLabel.draw(
                in: endRect,
                withAttributes: textAttributes
            )
        }

        private func drawCurrentTimeIndicator(configuration: WeeklyCalendarAppKitView) {
            let now = Date()
            guard now >= configuration.weekStart, now < configuration.weekEnd else { return }

            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            let weekday = calendar.component(.weekday, from: now)
            guard let dayIndex = configuration.dayOrder.firstIndex(of: weekday) else { return }

            let y = (CGFloat(hour) + CGFloat(minute) / 60) * configuration.hourHeight
            let x =
                calendarAreaX(configuration: configuration) + CGFloat(dayIndex)
                * dayColumnWidth(configuration: configuration)
            let width = dayColumnWidth(configuration: configuration)

            configuration.accentColor.setFill()
            let dotRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
            NSBezierPath(ovalIn: dotRect).fill()

            configuration.accentColor.setStroke()
            let line = NSBezierPath()
            line.lineWidth = 1
            line.move(to: CGPoint(x: x, y: y))
            line.line(to: CGPoint(x: x + width, y: y))
            line.stroke()
        }

        private func calendarAreaX(configuration: WeeklyCalendarAppKitView) -> CGFloat {
            configuration.timeLabelWidth + configuration.timeColumnGutter
        }

        private func dayColumnWidth(configuration: WeeklyCalendarAppKitView) -> CGFloat {
            max((bounds.width - calendarAreaX(configuration: configuration)) / 7, 1)
        }

        private func dayForPoint(_ point: CGPoint, configuration: WeeklyCalendarAppKitView) -> Int?
        {
            let calendarX = calendarAreaX(configuration: configuration)
            guard point.x >= calendarX else { return nil }
            let index = Int((point.x - calendarX) / dayColumnWidth(configuration: configuration))
            guard configuration.dayOrder.indices.contains(index) else { return nil }
            return configuration.dayOrder[index]
        }
    }

    private final class WeeklyCalendarScheduleBlockNSView: NSView {
        private var entry: WeeklyCalendarView.PositionedSchedule?
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
        private var interactionMode: WeeklyCalendarView.ScheduleInteractionMode?
        private var hasDragged = false
        private var isInteractionActive = false
        private var interactionPreviewLabels: (start: String, end: String)?

        override var isFlipped: Bool { true }

        func configure(
            entry: WeeklyCalendarView.PositionedSchedule,
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
            self.interactionPreviewLabels = nil
            self.frame = frame
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }

        override func resetCursorRects() {
            super.resetCursorRects()
            guard let entry else { return }

            if WeeklyCalendarView.canDirectlyManipulate(entry.schedule) {
                let handleHeight = WeeklyCalendarView.effectiveResizeHandleHeight(
                    boundsHeight: bounds.height,
                    preferredHeight: edgeHeight
                )
                addCursorRect(
                    CGRect(x: 0, y: 0, width: bounds.width, height: handleHeight),
                    cursor: .resizeUpDown)
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

            if WeeklyCalendarView.canDirectlyManipulate(entry.schedule) {
                let localPoint = convert(event.locationInWindow, from: nil)
                interactionMode = WeeklyCalendarView.interactionMode(
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
                WeeklyCalendarView.canDirectlyManipulate(entry.schedule),
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
                        WeeklyCalendarView.snappedMinuteDelta(
                            translationHeight: translation.height,
                            hourHeight: hourHeight
                        )
                    ) * hourHeight / 60
                snapped = CGSize(width: CGFloat(dayDelta) * columnWidth, height: snappedY)
            case .resizeStart, .resizeEnd:
                snapped = WeeklyCalendarView.snappedInteractionTranslation(
                    translation: translation,
                    mode: interactionMode,
                    columnWidth: columnWidth,
                    hourHeight: hourHeight
                )
            }
            hasDragged = abs(snapped.width) > 0 || abs(snapped.height) > 0
            if hasDragged {
                setInteractionPreviewLabels(
                    WeeklyCalendarView.schedulePreviewLabels(
                        placement: entry.placement,
                        translation: snapped,
                        mode: interactionMode,
                        hourHeight: hourHeight
                    )
                )
            } else {
                setInteractionPreviewLabels(nil)
            }
            let previewFrame = WeeklyCalendarView.previewFrame(
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
                let update = WeeklyCalendarView.scheduleUpdate(
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
                let baseColor = NSColor(schedule.themeColor)
                fillColor = baseColor.withAlphaComponent(
                    ScheduleBlockView.fillOpacity(isImported: isImported)
                )
                borderColor = baseColor.withAlphaComponent(
                    ScheduleBlockView.borderOpacity(isImported: isImported)
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
                named: ScheduleBlockView.primarySymbolName(for: schedule),
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

            if let importedSymbolName = ScheduleBlockView.importedSymbolName(for: schedule),
                let importedIcon = symbolImage(
                    named: importedSymbolName,
                    pointSize: 9,
                    weight: .bold,
                    color: .white
                )
            {
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
            (schedule.timeRangeString as NSString).draw(
                in: timeRect, withAttributes: timeAttributes)

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
            return WeeklyCalendarView.dayDelta(
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
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.white.withAlphaComponent(0.95),
            ]
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right
            paragraph.lineBreakMode = .byTruncatingTail
            let textAttributes = labelAttributes.merging([.paragraphStyle: paragraph]) { _, new in
                new
            }

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
            (labels.start as NSString).draw(
                in: startRect,
                withAttributes: textAttributes
            )

            let endRect = CGRect(
                x: horizontalInset,
                y: max(bounds.height - verticalInset - labelHeight, startRect.maxY),
                width: textWidth,
                height: labelHeight
            )
            (labels.end as NSString).draw(
                in: endRect,
                withAttributes: textAttributes
            )
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
#endif

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
                        Image(systemName: Self.primarySymbolName(for: schedule))
                            .font(.system(size: 10, weight: .bold))
                        Text(schedule.name)
                            .font(.caption)
                            .bold()
                        if let importedSymbolName = Self.importedSymbolName(for: schedule) {
                            Image(systemName: importedSymbolName)
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

    static func primarySymbolName(for schedule: Schedule) -> String {
        schedule.type == .focus ? "target" : "cup.and.saucer.fill"
    }

    static func importedSymbolName(for schedule: Schedule) -> String? {
        schedule.importedCalendarEventKey != nil ? "calendar.badge.clock" : nil
    }

    func timeRange(_ s: Schedule) -> String {
        s.timeRangeString
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
