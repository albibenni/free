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
}
