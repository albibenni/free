import CoreGraphics
import Foundation

extension WeeklyCalendarSupport {
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
                        laneIndex: laneAssignments[entry.placement.id, default: 0],
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

    static func canDirectlyManipulate(_ schedule: Schedule) -> Bool {
        schedule.importedCalendarEventKey == nil
    }

    static func dayName(for day: Int) -> String {
        Calendar.current.shortWeekdaySymbols[day - 1]
    }

    static func timeString(hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = calendarDateBuilder(Calendar.current, DateComponents(hour: hour)) ?? Date()
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

        let weekEnd = calendarDateAdder(calendar, .day, 1, weekLast) ?? weekLast.addingTimeInterval(86400)
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
        schedule.type == .focus ? AppKitUISymbols.Name.target : AppKitUISymbols.Name.breakCup
    }

    static func importedSymbolName(for schedule: Schedule) -> String? {
        schedule.importedCalendarEventKey != nil ? AppKitUISymbols.Name.importedCalendar : nil
    }
}
