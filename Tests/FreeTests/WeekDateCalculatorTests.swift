import Foundation
import Testing

@testable import FreeLogic

struct WeekDateCalculatorTests {
    @Test("WeekDateCalculator returns seven ordered days with live runtime")
    func liveRuntimeWeekDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = Date(timeIntervalSince1970: 1_708_387_200)

        let sundayWeek = WeekDateCalculator.getWeekDates(
            at: anchor,
            weekStartsOnMonday: false,
            calendar: calendar
        )
        #expect(sundayWeek.count == 7)
        #expect(calendar.component(.weekday, from: sundayWeek[0]) == 1)

        let mondayWeek = WeekDateCalculator.getWeekDates(
            at: anchor,
            weekStartsOnMonday: true,
            calendar: calendar
        )
        #expect(mondayWeek.count == 7)
        #expect(calendar.component(.weekday, from: mondayWeek[0]) == 2)
    }

    @Test("WeekDateCalculator returns empty array when addWeeks fails")
    func addWeeksFailure() {
        let runtime = WeekDateCalculatorRuntime(
            addWeeks: { _, _, _ in nil },
            weekInterval: { _, _ in
                Issue.record("weekInterval should not be called when addWeeks fails")
                return nil
            },
            addDays: { _, _, _ in nil }
        )

        let dates = WeekDateCalculator.getWeekDates(
            at: Date(),
            weekStartsOnMonday: false,
            runtime: runtime
        )

        #expect(dates.isEmpty)
    }

    @Test("WeekDateCalculator returns empty array when weekInterval fails")
    func weekIntervalFailure() {
        let runtime = WeekDateCalculatorRuntime(
            addWeeks: { _, _, date in date },
            weekInterval: { _, _ in nil },
            addDays: { _, _, _ in nil }
        )

        let dates = WeekDateCalculator.getWeekDates(
            at: Date(),
            weekStartsOnMonday: false,
            runtime: runtime
        )

        #expect(dates.isEmpty)
    }

    @Test("WeekDateCalculator compactMap drops nil day entries")
    func compactMapDropsNilDays() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let runtime = WeekDateCalculatorRuntime(
            addWeeks: { _, _, _ in start },
            weekInterval: { _, _ in DateInterval(start: start, duration: 7 * 24 * 60 * 60) },
            addDays: { _, dayOffset, startOfWeek in
                if dayOffset == 3 { return nil }
                return startOfWeek.addingTimeInterval(TimeInterval(dayOffset * 24 * 60 * 60))
            }
        )

        let dates = WeekDateCalculator.getWeekDates(
            at: start,
            weekStartsOnMonday: false,
            runtime: runtime
        )

        #expect(dates.count == 6)
    }
}
