import CoreGraphics
import Foundation

enum WeeklyCalendarSupport {
    typealias CalendarHourSetter = (Calendar, Int, Int, Date) -> Date?
    typealias CalendarDateBuilder = (Calendar, DateComponents) -> Date?
    typealias CalendarDateAdder = (Calendar, Calendar.Component, Int, Date) -> Date?

    static var calendarHourSetter: CalendarHourSetter = { calendar, hour, minute, anchor in
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: anchor)
    }

    static var calendarDateBuilder: CalendarDateBuilder = { calendar, components in
        calendar.date(from: components)
    }

    static var calendarDateAdder: CalendarDateAdder = { calendar, component, value, date in
        calendar.date(byAdding: component, value: value, to: date)
    }

    static func resetCalendarHooksForTesting() {
        calendarHourSetter = { calendar, hour, minute, anchor in
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: anchor)
        }
        calendarDateBuilder = { calendar, components in
            calendar.date(from: components)
        }
        calendarDateAdder = { calendar, component, value, date in
            calendar.date(byAdding: component, value: value, to: date)
        }
    }

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

    static func normalizedInterval(
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

    static func normalizedInterval(
        startDate: Date,
        endDate: Date,
        calendar: Calendar
    ) -> DateInterval {
        let anchor = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        let startHour = startComponents.hour!
        let startMinute = startComponents.minute!
        let endHour = endComponents.hour!
        let endMinute = endComponents.minute!

        let start: Date
        if let resolved = calendarHourSetter(calendar, startHour, startMinute, anchor) {
            start = resolved
        } else {
            start = anchor
        }

        var end: Date
        if let resolved = calendarHourSetter(calendar, endHour, endMinute, anchor) {
            end = resolved
        } else {
            end = anchor
        }
        if end <= start {
            end = calendarDateAdder(calendar, .day, 1, end) ?? end.addingTimeInterval(86400)
        }
        return DateInterval(start: start, end: end)
    }

    static func timeOnlyDate(from date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return calendarDateBuilder(calendar, DateComponents(hour: components.hour, minute: components.minute))
            ?? date
    }

    static func concurrentLaneCount(
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
