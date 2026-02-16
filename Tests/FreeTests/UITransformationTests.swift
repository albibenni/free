import Testing
import SwiftUI
import Foundation
@testable import FreeLogic

struct UITransformationTests {
    
    @Test("Time string formatting logic")
    func timeFormatting() {
        let appState = AppState(isTesting: true)
        
        #expect(appState.timeString(time: 60) == "01:00")
        #expect(appState.timeString(time: 3661) == "61:01") // Standard implementation behavior
        #expect(appState.timeString(time: 0) == "00:00")
    }

    @Test("FocusColor hex/integrity check")
    func colorIntegrity() {
        // Ensure we have at least 9 colors as defined in FocusColor
        #expect(FocusColor.all.count >= 9)
        
        // Ensure no two neighboring colors are identical (UX check)
        for i in 0..<(FocusColor.all.count - 1) {
            #expect(FocusColor.all[i] != FocusColor.all[i+1])
        }
    }

    @Test("Pomodoro duration calculation and snapping")
    func pomodoroCalculation() {
        let center = CGPoint(x: 100, y: 100)
        let maxMins: Double = 60
        
        // 1. Top (Calculates as 0 or 60 depending on float precision, snapped to 5 or 60)
        let top = CGPoint(x: 100, y: 50)
        let topResult = PomodoroTimerView.calculateDuration(location: top, center: center, maxMinutes: maxMins)
        #expect(topResult == 5 || topResult == 60) 
        
        // 2. Right (90 degrees -> 15 mins)
        let right = CGPoint(x: 150, y: 100)
        #expect(PomodoroTimerView.calculateDuration(location: right, center: center, maxMinutes: maxMins) == 15)
        
        // 3. Bottom (180 degrees -> 30 mins)
        let bottom = CGPoint(x: 100, y: 150)
        #expect(PomodoroTimerView.calculateDuration(location: bottom, center: center, maxMinutes: maxMins) == 30)
        
        // 4. Left (270 degrees -> 45 mins)
        let left = CGPoint(x: 50, y: 100)
        #expect(PomodoroTimerView.calculateDuration(location: left, center: center, maxMinutes: maxMins) == 45)
    }

    @Test("AppearanceMode mapping to ColorScheme")
    func appearanceModeMapping() {
        #expect(AppearanceMode.light.colorScheme == .light)
        #expect(AppearanceMode.dark.colorScheme == .dark)
        #expect(AppearanceMode.system.colorScheme == nil)
    }

    @Test("WeeklyCalendar day ordering")
    func dayOrdering() {
        // Starts Sunday
        let sunFirst = WeeklyCalendarView.getDayOrder(weekStartsOnMonday: false)
        #expect(sunFirst.first == 1) // Sunday
        #expect(sunFirst.last == 7)  // Saturday
        
        // Starts Monday
        let monFirst = WeeklyCalendarView.getDayOrder(weekStartsOnMonday: true)
        #expect(monFirst.first == 2) // Monday
        #expect(monFirst.last == 1)  // Sunday
    }

    @Test("WeeklyCalendar rect calculation math")
    func calendarRectMath() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 10, minute: 30))!
        let hourH: CGFloat = 100
        let colWidth: CGFloat = 200
        
        let rect = WeeklyCalendarView.calculateRect(startDate: start, endDate: end, colIndex: 0, columnWidth: colWidth, hourHeight: hourH)
        
        #expect(rect?.origin.y == 900) // 9:00 * 100
        #expect(rect?.size.height == 150) // 1.5 hours * 100
        #expect(rect?.size.width == 196) // 200 - 4 padding
    }

    @Test("RulesView suggestion filtering logic")
    func suggestionFiltering() {
        let existing = RuleSet(name: "Test", urls: ["google.com", "youtube.com/watch?v=123"])
        let suggestions = [
            "https://www.google.com",           // Duplicate (normalized)
            "https://github.com",               // New
            "https://youtube.com/watch?v=123",  // Duplicate (exact)
            "https://youtube.com/watch?v=456"   // New
        ]
        
        let filtered = RulesView.filterSuggestions(suggestions, existing: existing)
        
        #expect(filtered.count == 2)
        #expect(filtered.contains("https://github.com"))
        #expect(filtered.contains("https://youtube.com/watch?v=456"))
    }

    @Test("Negative: RulesView suggestion filtering with edge cases")
    func suggestionFilteringEdgeCases() {
        let existing = RuleSet(name: "Test", urls: ["google.com"])
        
        // 1. Empty input list
        #expect(RulesView.filterSuggestions([], existing: existing).isEmpty)
        
        // 2. Empty rule set (everything should pass through)
        let emptySet = RuleSet(name: "Empty", urls: [])
        let suggestions = ["a.com", "b.com"]
        #expect(RulesView.filterSuggestions(suggestions, existing: emptySet).count == 2)
        
        // 3. Malformed/Empty strings in suggestions
        // RuleSet.containsRule uses RuleMatcher.isAllowed which returns true for empty strings
        // So filter { !existing.containsRule("") } should remove them.
        let badSuggestions = ["", "   ", "github.com"]
        let filtered = RulesView.filterSuggestions(badSuggestions, existing: existing)
        #expect(filtered.count == 1) 
        #expect(filtered.contains("github.com"))
    }

    @Test("WeeklyCalendar week date ranges")
    func weekDateRange() {
        let calendar = Calendar.current
        let now = Date()
        
        // Sunday Start
        let sunDates = WeeklyCalendarView.getWeekDates(at: now, weekStartsOnMonday: false)
        #expect(sunDates.count == 7)
        #expect(calendar.component(.weekday, from: sunDates.first!) == 1) // Sunday
        
        // Monday Start
        let monDates = WeeklyCalendarView.getWeekDates(at: now, weekStartsOnMonday: true)
        #expect(monDates.count == 7)
        #expect(calendar.component(.weekday, from: monDates.first!) == 2) // Monday
        
        // Verify continuity
        for i in 0..<6 {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: sunDates[i])!
            #expect(calendar.isDate(nextDay, inSameDayAs: sunDates[i+1]))
        }
    }

    @Test("WeeklyCalendar overnight rect math")
    func overnightRectMath() {
        let calendar = Calendar.current
        let hourH: CGFloat = 100
        
        // 10 PM to 2 AM
        let start = calendar.date(from: DateComponents(hour: 22, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 2, minute: 0))!
        
        let rect = WeeklyCalendarView.calculateRect(startDate: start, endDate: end, colIndex: 0, columnWidth: 200, hourHeight: hourH)
        
        // Should fill from 22:00 to 24:00 (remainder of the day)
        #expect(rect?.origin.y == 2200)
        #expect(rect?.size.height == 200) // 2 hours remaining
    }

    @Test("WeeklyCalendar formatting helpers")
    func calendarFormatting() {
        // dayName (1 = Sunday)
        #expect(!WeeklyCalendarView.dayName(for: 1).isEmpty)
        
        // timeString (9 AM)
        let nineAM = WeeklyCalendarView.timeString(hour: 9)
        #expect(nineAM.contains("9"))
        
        // formatTime (9.25 -> 9:15)
        let nineFifteen = WeeklyCalendarView.formatTime(9.25)
        #expect(nineFifteen.contains("9"))
        #expect(nineFifteen.contains("15"))
    }

    @Test("WeeklyCalendar drag snapping logic")
    func dragSnapping() {
        let calendar = Calendar.current
        
        // 1. Snap 9.1 (approx 9:06) -> 9:00
        //    Snap 10.4 (approx 10:24) -> 10:30
        let result = WeeklyCalendarView.calculateDragSelection(startHour: 9.1, endHour: 10.4)
        
        #expect(calendar.component(.hour, from: result.start) == 9)
        #expect(calendar.component(.minute, from: result.start) == 0)
        
        #expect(calendar.component(.hour, from: result.end) == 10)
        #expect(calendar.component(.minute, from: result.end) == 30)
    }

    @Test("Negative: WeeklyCalendar rect calculation with invalid range")
    func calendarRectNegative() {
        let calendar = Calendar.current
        let hourH: CGFloat = 100
        
        // 10:00 to 9:00 (End before start - non-overnight format)
        let start = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        
        let rect = WeeklyCalendarView.calculateRect(startDate: start, endDate: end, colIndex: 0, columnWidth: 200, hourHeight: hourH)
        
        // Current implementation treats start >= end as "rest of the day" (24:00)
        #expect(rect?.size.height == 1400) // (24 - 10) * 100
    }
}
