import Foundation

struct WeekDateCalculator {
    static func getWeekDates(
        at date: Date = Date(),
        weekStartsOnMonday: Bool,
        offset: Int = 0,
        calendar baseCalendar: Calendar = .current
    ) -> [Date] {
        var calendar = baseCalendar
        calendar.firstWeekday = weekStartsOnMonday ? 2 : 1

        guard
            let targetDate = calendar.date(byAdding: .weekOfYear, value: offset, to: date),
            let interval = calendar.dateInterval(of: .weekOfYear, for: targetDate)
        else {
            return []
        }

        let startOfWeek = interval.start
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }
}
