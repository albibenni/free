import Foundation

struct WeekDateCalculatorRuntime {
    var addWeeks: (_ calendar: Calendar, _ offset: Int, _ date: Date) -> Date?
    var weekInterval: (_ calendar: Calendar, _ date: Date) -> DateInterval?
    var addDays: (_ calendar: Calendar, _ dayOffset: Int, _ startOfWeek: Date) -> Date?

    static let live = WeekDateCalculatorRuntime(
        addWeeks: { calendar, offset, date in
            calendar.date(byAdding: .weekOfYear, value: offset, to: date)
        },
        weekInterval: { calendar, date in
            calendar.dateInterval(of: .weekOfYear, for: date)
        },
        addDays: { calendar, dayOffset, startOfWeek in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    )
}

struct WeekDateCalculator {
    static func getWeekDates(
        at date: Date = Date(),
        weekStartsOnMonday: Bool,
        offset: Int = 0,
        calendar baseCalendar: Calendar = .current,
        runtime: WeekDateCalculatorRuntime = .live
    ) -> [Date] {
        var calendar = baseCalendar
        calendar.firstWeekday = weekStartsOnMonday ? 2 : 1

        guard
            let targetDate = runtime.addWeeks(calendar, offset, date),
            let interval = runtime.weekInterval(calendar, targetDate)
        else {
            return []
        }

        let startOfWeek = interval.start
        return (0..<7).compactMap { day in
            runtime.addDays(calendar, day, startOfWeek)
        }
    }
}
