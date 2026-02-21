import Foundation
import SwiftUI
import Testing

@testable import FreeLogic

struct UITransformationTests {

    @Test("Time string formatting logic")
    func timeFormatting() {
        let appState = AppState(isTesting: true)

        #expect(appState.timeString(time: 60) == "01:00")
        #expect(appState.timeString(time: 3661) == "61:01")
        #expect(appState.timeString(time: 0) == "00:00")
    }

    @Test("FocusColor hex/integrity check")
    func colorIntegrity() {
        #expect(FocusColor.all.count >= 9)

        for i in 0..<(FocusColor.all.count - 1) {
            #expect(FocusColor.all[i] != FocusColor.all[i + 1])
        }
    }

    @Test("Pomodoro duration calculation and snapping")
    func pomodoroCalculation() {
        let center = CGPoint(x: 100, y: 100)
        let maxMins: Double = 60

        let top = CGPoint(x: 100, y: 50)
        let topResult = PomodoroTimerView.calculateDuration(
            location: top, center: center, maxMinutes: maxMins)
        #expect(topResult == 5 || topResult == 60)

        let right = CGPoint(x: 150, y: 100)
        #expect(
            PomodoroTimerView.calculateDuration(
                location: right, center: center, maxMinutes: maxMins) == 15)

        let bottom = CGPoint(x: 100, y: 150)
        #expect(
            PomodoroTimerView.calculateDuration(
                location: bottom, center: center, maxMinutes: maxMins) == 30)

        let left = CGPoint(x: 50, y: 100)
        #expect(
            PomodoroTimerView.calculateDuration(location: left, center: center, maxMinutes: maxMins)
                == 45)
    }

    @Test("AppearanceMode mapping to ColorScheme")
    func appearanceModeMapping() {
        #expect(AppearanceMode.light.colorScheme == .light)
        #expect(AppearanceMode.dark.colorScheme == .dark)
        #expect(AppearanceMode.system.colorScheme == nil)
    }

    @Test("WeeklyCalendar day ordering")
    func dayOrdering() {
        let sunFirst = WeeklyCalendarView.getDayOrder(weekStartsOnMonday: false)
        #expect(sunFirst.first == 1)
        #expect(sunFirst.last == 7)

        let monFirst = WeeklyCalendarView.getDayOrder(weekStartsOnMonday: true)
        #expect(monFirst.first == 2)
        #expect(monFirst.last == 1)
    }

    @Test("WeeklyCalendar rect calculation math")
    func calendarRectMath() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 10, minute: 30))!
        let hourH: CGFloat = 100
        let colWidth: CGFloat = 200

        let rect = WeeklyCalendarView.calculateRect(
            startDate: start, endDate: end, colIndex: 0, columnWidth: colWidth, hourHeight: hourH)

        #expect(rect?.origin.y == 900)
        #expect(rect?.size.height == 150)
        #expect(rect?.size.width == 196)
    }

    @Test("RulesView suggestion filtering logic")
    func suggestionFiltering() {
        let existing = RuleSet(name: "Test", urls: ["google.com", "youtube.com/watch?v=123"])
        let suggestions = [
            "https://www.google.com",
            "https://github.com",
            "https://youtube.com/watch?v=123",
            "https://youtube.com/watch?v=456",
        ]

        let filtered = RulesView.filterSuggestions(suggestions, existing: existing)

        #expect(filtered.count == 2)
        #expect(filtered.contains("https://github.com"))
        #expect(filtered.contains("https://youtube.com/watch?v=456"))
    }

    @Test("Negative: RulesView suggestion filtering with edge cases")
    func suggestionFilteringEdgeCases() {
        let existing = RuleSet(name: "Test", urls: ["google.com"])

        #expect(RulesView.filterSuggestions([], existing: existing).isEmpty)

        let emptySet = RuleSet(name: "Empty", urls: [])
        let suggestions = ["a.com", "b.com"]
        #expect(RulesView.filterSuggestions(suggestions, existing: emptySet).count == 2)

        let badSuggestions = ["", "   ", "github.com"]
        let filtered = RulesView.filterSuggestions(badSuggestions, existing: existing)
        #expect(filtered.count == 1)
        #expect(filtered.contains("github.com"))
    }

    @Test("WeeklyCalendar week date ranges")
    func weekDateRange() {
        let calendar = Calendar.current
        let now = Date()

        let sunDates = WeeklyCalendarView.getWeekDates(at: now, weekStartsOnMonday: false)
        #expect(sunDates.count == 7)
        #expect(calendar.component(.weekday, from: sunDates.first!) == 1)

        let monDates = WeeklyCalendarView.getWeekDates(at: now, weekStartsOnMonday: true)
        #expect(monDates.count == 7)
        #expect(calendar.component(.weekday, from: monDates.first!) == 2)

        let nextWeek = WeeklyCalendarView.getWeekDates(
            at: now, weekStartsOnMonday: false, offset: 1)
        #expect(nextWeek.count == 7)
        let diff = calendar.dateComponents([.day], from: sunDates.first!, to: nextWeek.first!).day
        #expect(diff == 7)

        for i in 0..<6 {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: sunDates[i])!
            #expect(calendar.isDate(nextDay, inSameDayAs: sunDates[i + 1]))
        }
    }

    @Test("WeeklyCalendar overnight rect math")
    func overnightRectMath() {
        let calendar = Calendar.current
        let hourH: CGFloat = 100

        let start = calendar.date(from: DateComponents(hour: 22, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 2, minute: 0))!

        let rect = WeeklyCalendarView.calculateRect(
            startDate: start, endDate: end, colIndex: 0, columnWidth: 200, hourHeight: hourH)

        #expect(rect?.origin.y == 2200)
        #expect(rect?.size.height == 200)
    }

    @Test("WeeklyCalendar formatting helpers")
    func calendarFormatting() {
        #expect(!WeeklyCalendarView.dayName(for: 1).isEmpty)

        let nineAM = WeeklyCalendarView.timeString(hour: 9)
        #expect(nineAM.contains("9"))

        let nineFifteen = WeeklyCalendarView.formatTime(9.25)
        #expect(nineFifteen.contains("9"))
        #expect(nineFifteen.contains("15"))
    }

    @Test("WeeklyCalendar drag snapping logic")
    func dragSnapping() {
        let calendar = Calendar.current

        let result = WeeklyCalendarView.calculateDragSelection(startHour: 9.1, endHour: 10.4)

        #expect(calendar.component(.hour, from: result.start) == 9)
        #expect(calendar.component(.minute, from: result.start) == 0)

        #expect(calendar.component(.hour, from: result.end) == 10)
        #expect(calendar.component(.minute, from: result.end) == 30)
    }

    @Test("WeeklyCalendar year transition edge case")
    func calendarYearTransition() {
        let calendar = Calendar.current
        let nye = calendar.date(from: DateComponents(year: 2023, month: 12, day: 31))!

        let dates = WeeklyCalendarView.getWeekDates(at: nye, weekStartsOnMonday: false)
        #expect(dates.count == 7)
        #expect(calendar.component(.year, from: dates.first!) == 2023)
        #expect(calendar.component(.year, from: dates.last!) == 2024)
        #expect(calendar.component(.month, from: dates.last!) == 1)
    }

    @Test("WeeklyCalendar rect calculation extreme edges")
    func calendarRectExtremeEdges() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 12, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 12, minute: 1))!

        let rect = WeeklyCalendarView.calculateRect(
            startDate: start, endDate: end, colIndex: 0, columnWidth: 100, hourHeight: 100)
        #expect(rect?.size.height == 15)

        let narrowRect = WeeklyCalendarView.calculateRect(
            startDate: start, endDate: end, colIndex: 0, columnWidth: 2, hourHeight: 100)
        #expect(narrowRect?.size.width == -2)
    }

    @Test("WeeklyCalendar zero-duration drag selection")
    func zeroDurationDrag() {
        let calendar = Calendar.current
        let result = WeeklyCalendarView.calculateDragSelection(startHour: 14.0, endHour: 14.0)

        let duration = result.end.timeIntervalSince(result.start)
        #expect(duration == 900)
        #expect(calendar.component(.hour, from: result.start) == 14)
        #expect(calendar.component(.minute, from: result.end) == 15)
    }

    @Test("Negative: WeeklyCalendar rect calculation with invalid range")
    func calendarRectNegative() {
        let calendar = Calendar.current
        let hourH: CGFloat = 100

        let start = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 9, minute: 0))!

        let rect = WeeklyCalendarView.calculateRect(
            startDate: start, endDate: end, colIndex: 0, columnWidth: 200, hourHeight: hourH)

        #expect(rect?.size.height == 1400)
    }
}
