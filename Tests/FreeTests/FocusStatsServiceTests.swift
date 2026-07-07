import Foundation
import Testing

@testable import FreeLogic

@Suite("FocusStatsService")
struct FocusStatsServiceTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = mo; comps.day = d; comps.hour = h; comps.minute = mi
        return calendar.date(from: comps)!
    }

    @Test("rolledOver keeps the total on the same day")
    func rolledOverSameDay() {
        let day = calendar.startOfDay(for: date(2026, 7, 7))
        let stats = FocusStatsService.Stats(secondsToday: 1234, day: day)
        let result = FocusStatsService.rolledOver(stats, now: date(2026, 7, 7, 23, 59), calendar: calendar)
        #expect(result == stats)
    }

    @Test("rolledOver resets the total on a new day")
    func rolledOverNewDay() {
        let stats = FocusStatsService.Stats(
            secondsToday: 3600,
            day: calendar.startOfDay(for: date(2026, 7, 6))
        )
        let result = FocusStatsService.rolledOver(stats, now: date(2026, 7, 7), calendar: calendar)
        #expect(result.secondsToday == 0)
        #expect(result.day == calendar.startOfDay(for: date(2026, 7, 7)))
    }

    @Test("folding adds the elapsed interval")
    func foldingAddsElapsed() {
        let day = calendar.startOfDay(for: date(2026, 7, 7))
        let stats = FocusStatsService.Stats(secondsToday: 100, day: day)
        let start = date(2026, 7, 7, 10, 0)
        let now = date(2026, 7, 7, 10, 5) // +300s
        let result = FocusStatsService.folding(stats, intervalStart: start, now: now, calendar: calendar)
        #expect(result.secondsToday == 400)
        #expect(result.day == day)
    }

    @Test("folding ignores non-positive spans")
    func foldingIgnoresNonPositive() {
        let day = calendar.startOfDay(for: date(2026, 7, 7))
        let stats = FocusStatsService.Stats(secondsToday: 100, day: day)
        let start = date(2026, 7, 7, 10, 5)
        let now = date(2026, 7, 7, 10, 0) // start after now
        let result = FocusStatsService.folding(stats, intervalStart: start, now: now, calendar: calendar)
        #expect(result.secondsToday == 100)
    }

    @Test("folding across midnight counts only the current day and resets")
    func foldingAcrossMidnight() {
        // Total belongs to the previous day; interval started before midnight.
        let stats = FocusStatsService.Stats(
            secondsToday: 500,
            day: calendar.startOfDay(for: date(2026, 7, 6))
        )
        let start = date(2026, 7, 6, 23, 40) // 20 min before midnight
        let now = date(2026, 7, 7, 0, 10) // 10 min after midnight
        let result = FocusStatsService.folding(stats, intervalStart: start, now: now, calendar: calendar)
        // Rolled over to the 7th (previous 500s dropped), only the 10 min after
        // midnight counted.
        #expect(result.day == calendar.startOfDay(for: date(2026, 7, 7)))
        #expect(result.secondsToday == 600)
    }
}
