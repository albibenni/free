import CoreGraphics
import Foundation

extension WeeklyCalendarSupport {
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
}
