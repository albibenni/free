import CoreGraphics
import Foundation

enum WeeklyCalendarSupport {
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

    struct ScheduleUpdate {
        let targetDay: Int
        let targetDate: Date?
        let start: Date
        let end: Date
    }

    static func getDayOrder(weekStartsOnMonday: Bool) -> [Int] {
        weekStartsOnMonday ? [2, 3, 4, 5, 6, 7, 1] : [1, 2, 3, 4, 5, 6, 7]
    }

    static func getWeekDates(
        at date: Date = Date(),
        weekStartsOnMonday: Bool,
        offset: Int = 0
    ) -> [Date] {
        WeekDateCalculator.getWeekDates(
            at: date,
            weekStartsOnMonday: weekStartsOnMonday,
            offset: offset
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
        let snap = { (hour: CGFloat) -> CGFloat in
            (hour * 4).rounded() / 4.0
        }

        let startHour = snap(min(data.startHour, data.endHour))
        let endHour = snap(max(data.startHour, data.endHour))
        let yOffset = startHour * hourHeight
        let height = max(endHour - startHour, 0.25) * hourHeight

        guard let columnIndex = dayOrder.firstIndex(of: data.day) else {
            return nil
        }

        return DragPreviewMetrics(
            columnWidth: columnWidth,
            startHour: startHour,
            endHour: endHour,
            yOffset: yOffset,
            height: height,
            columnIndex: columnIndex
        )
    }

    static func formatTime(_ hour: CGFloat) -> String {
        let wholeHour = Int(hour)
        let minute = Int(((hour - CGFloat(wholeHour)) * 60).rounded())
        let date = Calendar.current.date(from: DateComponents(hour: wholeHour, minute: minute))!
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

    static func calculateDragSelection(
        startHour: CGFloat,
        endHour: CGFloat
    ) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let (snappedStart, snappedEnd) = snappedSelectionHours(
            startHour: startHour,
            endHour: endHour
        )

        let startHourValue = Int(snappedStart)
        let startMinuteValue = Int(((snappedStart - CGFloat(startHourValue)) * 60).rounded())
        let endHourValue = Int(snappedEnd)
        let endMinuteValue = Int(((snappedEnd - CGFloat(endHourValue)) * 60).rounded())

        let start = calendar.date(
            from: DateComponents(hour: startHourValue, minute: startMinuteValue)
        )!
        let end = calendar.date(
            from: DateComponents(hour: endHourValue, minute: endMinuteValue)
        )!
        return (start, end)
    }

    static func selectionPreviewLabels(
        startHour: CGFloat,
        endHour: CGFloat
    ) -> (start: String, end: String) {
        let (snappedStart, snappedEnd) = snappedSelectionHours(
            startHour: startHour,
            endHour: endHour
        )
        return (formatTime(snappedStart), formatTime(snappedEnd))
    }

    static func snappedSelectionHours(
        startHour: CGFloat,
        endHour: CGFloat
    ) -> (start: CGFloat, end: CGFloat) {
        let snap = { (hour: CGFloat) -> CGFloat in
            (hour * 4).rounded() / 4.0
        }

        let snappedStart = snap(min(startHour, endHour))
        var snappedEnd = snap(max(startHour, endHour))
        if snappedEnd - snappedStart < 0.25 {
            snappedEnd = snappedStart + 0.25
        }
        return (snappedStart, snappedEnd)
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
                ? snappedDayDelta(
                    translationWidth: translation.width,
                    columnWidth: columnWidth
                )
                : 0)
        let minuteDelta = snappedMinuteDelta(
            translationHeight: translation.height,
            hourHeight: hourHeight
        )
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
                interval.end.addingTimeInterval(-minimumDuration)
            )
            updatedInterval = DateInterval(start: newStart, end: interval.end)
        case .resizeEnd:
            let newEnd = max(
                interval.end.addingTimeInterval(delta),
                interval.start.addingTimeInterval(minimumDuration)
            )
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

    static func dayName(for day: Int) -> String {
        Calendar.current.shortWeekdaySymbols[day - 1]
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

    static func monthYearString(
        for date: Date,
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    static func weekBounds(
        for weekRange: [Date],
        calendar: Calendar = .current
    ) -> (Date, Date) {
        guard let weekStart = weekRange.first, let weekLast = weekRange.last else {
            return (.distantPast, .distantFuture)
        }

        let weekEnd = calendar.date(byAdding: .day, value: 1, to: weekLast)!
        return (weekStart, weekEnd)
    }

    static func visibleCalendarEvents(
        _ events: [ExternalEvent],
        weekStart: Date,
        weekEnd: Date
    ) -> [ExternalEvent] {
        events.filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
    }

    static func shouldDisplaySchedule(
        _ schedule: Schedule,
        weekStart: Date,
        weekEnd: Date,
        calendar: Calendar = .current
    ) -> Bool {
        if let specificDate = schedule.date {
            let scheduleDay = calendar.startOfDay(for: specificDate)
            let weekStartDay = calendar.startOfDay(for: weekStart)
            let weekEndDay = calendar.startOfDay(for: weekEnd)
            return scheduleDay >= weekStartDay && scheduleDay < weekEndDay
        }
        return true
    }

    static func schedulePlacements(
        for schedule: Schedule,
        weekRange: [Date],
        calendar: Calendar = .current
    ) -> [SchedulePlacement] {
        if let specificDate = schedule.date {
            guard let inWeekDate = weekRange.first(where: {
                calendar.isDate($0, inSameDayAs: specificDate)
            }) else {
                return []
            }

            return [
                SchedulePlacement(
                    id: "\(schedule.id.uuidString)-\(calendar.startOfDay(for: inWeekDate).timeIntervalSince1970)",
                    day: calendar.component(.weekday, from: inWeekDate),
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

    static func positionedSchedules(
        schedules: [Schedule],
        weekRange: [Date],
        calendar: Calendar = .current
    ) -> [PositionedSchedule] {
        let bounds = weekBounds(for: weekRange, calendar: calendar)
        let visible = schedules.filter {
            shouldDisplaySchedule($0, weekStart: bounds.0, weekEnd: bounds.1, calendar: calendar)
        }
        let placements = visible.flatMap { schedule in
            schedulePlacements(for: schedule, weekRange: weekRange, calendar: calendar).map {
                (schedule: schedule, placement: $0)
            }
        }
        return positionedSchedules(from: placements, calendar: calendar)
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
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)

        let startHour = startComponents.hour!
        let startMinute = startComponents.minute!
        let endHour = endComponents.hour!
        let endMinute = endComponents.minute!

        let startY = (CGFloat(startHour) + CGFloat(startMinute) / 60.0) * hourHeight
        var endY = (CGFloat(endHour) + CGFloat(endMinute) / 60.0) * hourHeight
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

    static func blockFillOpacity(isImported: Bool) -> Double {
        isImported ? 0.5 : 0.8
    }

    static func blockBorderOpacity(isImported: Bool) -> Double {
        isImported ? 0.72 : 0.95
    }

    static func primarySymbolName(for schedule: Schedule) -> String {
        schedule.type == .focus ? "target" : "cup.and.saucer.fill"
    }

    static func importedSymbolName(for schedule: Schedule) -> String? {
        schedule.importedCalendarEventKey != nil ? "calendar.badge.clock" : nil
    }

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
        let candidateEnds = placements.map {
            normalizedInterval(for: $0, calendar: calendar).end
        }
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
