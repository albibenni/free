import Foundation
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
        let topResult = PomodoroTimerSupport.calculateDuration(
            location: top, center: center, maxMinutes: maxMins)
        #expect(topResult == 5 || topResult == 60)

        let right = CGPoint(x: 150, y: 100)
        #expect(
            PomodoroTimerSupport.calculateDuration(
                location: right, center: center, maxMinutes: maxMins) == 15)

        let bottom = CGPoint(x: 100, y: 150)
        #expect(
            PomodoroTimerSupport.calculateDuration(
                location: bottom, center: center, maxMinutes: maxMins) == 30)

        let left = CGPoint(x: 50, y: 100)
        #expect(
            PomodoroTimerSupport.calculateDuration(
                location: left,
                center: center,
                maxMinutes: maxMins
            )
                == 45)
    }

    @Test("WeeklyCalendar day ordering")
    func dayOrdering() {
        let sunFirst = WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: false)
        #expect(sunFirst.first == 1)
        #expect(sunFirst.last == 7)

        let monFirst = WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: true)
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

        let rect = WeeklyCalendarSupport.calculateRect(
            startDate: start, endDate: end, colIndex: 0, columnWidth: colWidth, hourHeight: hourH)

        #expect(rect?.origin.y == 900)
        #expect(rect?.size.height == 150)
        #expect(rect?.size.width == 196)
    }

    @Test("Rules section suggestion filtering logic")
    func suggestionFiltering() {
        let existing = RuleSet(name: "Test", urls: ["google.com", "youtube.com/watch?v=123"])
        let suggestions = [
            "https://www.google.com",
            "https://github.com",
            "https://youtube.com/watch?v=123",
            "https://youtube.com/watch?v=456",
        ]

        let filtered = RulesSectionSupport.filterSuggestions(suggestions, existing: existing)

        #expect(filtered.count == 2)
        #expect(filtered.contains("https://github.com"))
        #expect(filtered.contains("https://youtube.com/watch?v=456"))
    }

    @Test("Negative: rules section suggestion filtering with edge cases")
    func suggestionFilteringEdgeCases() {
        let existing = RuleSet(name: "Test", urls: ["google.com"])

        #expect(RulesSectionSupport.filterSuggestions([], existing: existing).isEmpty)

        let emptySet = RuleSet(name: "Empty", urls: [])
        let suggestions = ["a.com", "b.com"]
        #expect(RulesSectionSupport.filterSuggestions(suggestions, existing: emptySet).count == 2)

        let badSuggestions = ["", "   ", "github.com"]
        let filtered = RulesSectionSupport.filterSuggestions(badSuggestions, existing: existing)
        #expect(filtered.count == 1)
        #expect(filtered.contains("github.com"))
    }

    @Test("WeeklyCalendar week date ranges")
    func weekDateRange() {
        let calendar = Calendar.current
        let now = Date()

        let sunDates = WeeklyCalendarSupport.getWeekDates(at: now, weekStartsOnMonday: false)
        #expect(sunDates.count == 7)
        #expect(calendar.component(.weekday, from: sunDates.first!) == 1)

        let monDates = WeeklyCalendarSupport.getWeekDates(at: now, weekStartsOnMonday: true)
        #expect(monDates.count == 7)
        #expect(calendar.component(.weekday, from: monDates.first!) == 2)

        let nextWeek = WeeklyCalendarSupport.getWeekDates(
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

        let rect = WeeklyCalendarSupport.calculateRect(
            startDate: start, endDate: end, colIndex: 0, columnWidth: 200, hourHeight: hourH)

        #expect(rect?.origin.y == 2200)
        #expect(rect?.size.height == 200)
    }

    @Test("WeeklyCalendar formatting helpers")
    func calendarFormatting() {
        #expect(!WeeklyCalendarSupport.dayName(for: 1).isEmpty)

        let nineAM = WeeklyCalendarSupport.timeString(hour: 9)
        #expect(nineAM.contains("9"))

        let nineFifteen = WeeklyCalendarSupport.formatTime(9.25)
        #expect(nineFifteen.contains("9"))
        #expect(nineFifteen.contains("15"))
    }

    @Test("WeeklyCalendar drag snapping logic")
    func dragSnapping() {
        let calendar = Calendar.current

        let result = WeeklyCalendarSupport.calculateDragSelection(startHour: 9.1, endHour: 10.4)

        #expect(calendar.component(.hour, from: result.start) == 9)
        #expect(calendar.component(.minute, from: result.start) == 0)

        #expect(calendar.component(.hour, from: result.end) == 10)
        #expect(calendar.component(.minute, from: result.end) == 30)
    }

    @Test("WeeklyCalendar year transition edge case")
    func calendarYearTransition() {
        let calendar = Calendar.current
        let nye = calendar.date(from: DateComponents(year: 2023, month: 12, day: 31))!

        let dates = WeeklyCalendarSupport.getWeekDates(at: nye, weekStartsOnMonday: false)
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

        let rect = WeeklyCalendarSupport.calculateRect(
            startDate: start, endDate: end, colIndex: 0, columnWidth: 100, hourHeight: 100)
        #expect(rect?.size.height == 15)

        let narrowRect = WeeklyCalendarSupport.calculateRect(
            startDate: start, endDate: end, colIndex: 0, columnWidth: 2, hourHeight: 100)
        #expect(narrowRect?.size.width == 1)
    }

    @Test("WeeklyCalendar zero-duration drag selection")
    func zeroDurationDrag() {
        let calendar = Calendar.current
        let result = WeeklyCalendarSupport.calculateDragSelection(startHour: 14.0, endHour: 14.0)

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

        let rect = WeeklyCalendarSupport.calculateRect(
            startDate: start, endDate: end, colIndex: 0, columnWidth: 200, hourHeight: hourH)

        #expect(rect?.size.height == 1400)
    }

    @Test("WeeklyCalendar support models and lane calculation cover initializer-heavy branches")
    func weeklyCalendarSupportModelCoverage() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        let schedule = Schedule(
            name: "Focus",
            days: [2],
            startTime: start,
            endTime: end
        )

        let dragSelection = WeeklyCalendarSupport.DragSelection(day: 2, startHour: 9.0, endHour: 10.0)
        #expect(dragSelection.day == 2)

        let metrics = WeeklyCalendarSupport.DragPreviewMetrics(
            columnWidth: 100,
            startHour: 9,
            endHour: 10,
            yOffset: 0,
            height: 80,
            columnIndex: 1
        )
        #expect(metrics.columnIndex == 1)

        let placement = WeeklyCalendarSupport.SchedulePlacement(
            id: "placement",
            day: 2,
            startDate: start,
            endDate: end
        )
        let positioned = WeeklyCalendarSupport.PositionedSchedule(
            id: "pos",
            schedule: schedule,
            placement: placement,
            laneIndex: 0,
            laneCount: 1
        )
        #expect(positioned.laneCount == 1)

        let update = WeeklyCalendarSupport.ScheduleUpdate(
            targetDay: 3,
            targetDate: Date(),
            start: start,
            end: end
        )
        #expect(update.targetDay == 3)

        let moveMode: WeeklyCalendarSupport.ScheduleInteractionMode = .move
        let resizeStartMode: WeeklyCalendarSupport.ScheduleInteractionMode = .resizeStart
        let resizeEndMode: WeeklyCalendarSupport.ScheduleInteractionMode = .resizeEnd
        #expect(moveMode != resizeStartMode)
        #expect(resizeEndMode != resizeStartMode)

        let laneCount = WeeklyCalendarSupport.concurrentLaneCount(
            for: placement,
            among: [placement],
            calendar: calendar
        )
        #expect(laneCount == 1)

        WeeklyCalendarSupport.calendarHourSetter = { _, _, _, _ in nil }
        WeeklyCalendarSupport.calendarDateBuilder = { _, _ in nil }
        defer { WeeklyCalendarSupport.resetCalendarHooksForTesting() }

        let fallbackInterval = WeeklyCalendarSupport.normalizedInterval(
            startDate: start,
            endDate: end,
            calendar: calendar
        )
        #expect(fallbackInterval.start == calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0)))

        let fallbackTimeOnly = WeeklyCalendarSupport.timeOnlyDate(from: Date(), calendar: calendar)
        #expect(fallbackTimeOnly.timeIntervalSinceReferenceDate >= 0)

        WeeklyCalendarSupport.resetCalendarHooksForTesting()
        let source = calendar.date(from: DateComponents(hour: 8, minute: 45))!
        let rebuilt = WeeklyCalendarSupport.timeOnlyDate(from: source, calendar: calendar)
        #expect(calendar.component(.hour, from: rebuilt) == 8)
        #expect(calendar.component(.minute, from: rebuilt) == 45)
    }

    @Test("Rules section support import candidates cover excluded scheme and malformed fallback paths")
    func rulesImportCandidatesCoverage() {
        let existing = RuleSet(
            name: "Existing",
            urls: ["youtube.com/watch?v=abc"]
        )
        let inputs = [
            "chrome://newtab",
            "https://example.com/with path",
            "https:///only/path",
            "youtube.com/watch?v=abc",
            "youtube.com/watch?v=abc",
            "https://www.apple.com",
        ]

        let candidates = RulesSectionSupport.importableWebsiteCandidates(from: inputs, existing: existing)
        #expect(candidates.count == 4)
        #expect(candidates.contains { $0.rule.contains("example.com/with path") && !$0.isAlreadyAllowed })
        #expect(candidates.contains { $0.rule.contains("only/path") && !$0.isAlreadyAllowed })
        #expect(candidates.contains { $0.rule.contains("apple.com") && !$0.isAlreadyAllowed })
        #expect(candidates.contains { $0.rule.contains("youtube.com/watch?v=abc") && $0.isAlreadyAllowed })

        let noExistingCandidates = RulesSectionSupport.importableWebsiteCandidates(
            from: ["example.org/page"],
            existing: nil
        )
        #expect(noExistingCandidates.count == 1)
        #expect(noExistingCandidates.first?.isAlreadyAllowed == false)

        #expect(RulesSectionSupport.shouldShowDeleteSetButton(ruleSetCount: 1, isBlocking: false) == false)
        #expect(RulesSectionSupport.shouldShowDeleteSetButton(ruleSetCount: 2, isBlocking: false))
        #expect(RulesSectionSupport.sidebarToggleIcon(isSidebarVisible: true) == AppKitUISymbols.Name.chevronLeft)
        #expect(
            RulesSectionSupport.sidebarToggleIcon(isSidebarVisible: false) == AppKitUISymbols.Name.chevronRight
        )
    }
}
