import Testing
import Foundation
@testable import FreeLogic

struct ScheduleTests {
    
    @Test("Schedule activates correctly within time range")
    func scheduleActiveInTimeRange() {
        // Given
        var schedule = Schedule(
            name: "Test Schedule",
            days: [2], // Monday (assuming Gregorian)
            startTime: Date(),
            endTime: Date(),
            isEnabled: true
        )
        
        let calendar = Calendar.current
        // Set Monday 10:00 AM
        let monday = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2, hour: 10, minute: 0))! 
        // 2023-01-02 is a Monday
        
        // Schedule is 9:00 - 17:00
        schedule.startTime = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        schedule.endTime = calendar.date(from: DateComponents(hour: 17, minute: 0))!
        
        // When
        let isActive = schedule.isActive(at: monday)
        
        // Then
        #expect(isActive, "Schedule should be active on Monday 10:00")
    }
    
    @Test("Schedule remains inactive on wrong day")
    func scheduleInactiveWrongDay() {
        // Given
        var schedule = Schedule(
            name: "Test Schedule",
            days: [2], // Monday
            startTime: Date(),
            endTime: Date(),
            isEnabled: true
        )
        
        let calendar = Calendar.current
        // Tuesday 10:00 AM
        let tuesday = calendar.date(from: DateComponents(year: 2023, month: 1, day: 3, hour: 10, minute: 0))!
        
        schedule.startTime = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        schedule.endTime = calendar.date(from: DateComponents(hour: 17, minute: 0))!
        
        // When
        let isActive = schedule.isActive(at: tuesday)
        
        // Then
        #expect(!isActive, "Schedule should be inactive on Tuesday")
    }
    
    @Test("Overnight schedule logic works correctly")
    func scheduleOvernight() {
        // Given
        var schedule = Schedule(
            name: "Night Shift",
            days: [2], // Monday
            startTime: Date(),
            endTime: Date(),
            isEnabled: true
        )
        
        let calendar = Calendar.current
        // Schedule 22:00 - 02:00
        schedule.startTime = calendar.date(from: DateComponents(hour: 22, minute: 0))!
        schedule.endTime = calendar.date(from: DateComponents(hour: 2, minute: 0))!
        
        // Monday 23:00 (Should be active)
        let mondayNight = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2, hour: 23, minute: 0))!
        // Monday 01:00 (Should be active)
        let mondayMorning = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2, hour: 1, minute: 0))!
        // Monday 12:00 (Should be inactive)
        let mondayNoon = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2, hour: 12, minute: 0))!
        
        // Then
        #expect(schedule.isActive(at: mondayNight), "Should be active at 23:00")
        #expect(schedule.isActive(at: mondayMorning), "Should be active at 01:00")
        #expect(!schedule.isActive(at: mondayNoon), "Should be inactive at 12:00")
    }

    @Test("Schedule disabled state")
    func scheduleDisabled() {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        
        var schedule = Schedule(
            name: "Disabled",
            days: [weekday],
            startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(3600),
            isEnabled: false
        )
        
        #expect(!schedule.isActive(at: now), "Disabled schedule should never be active")
        
        schedule.isEnabled = true
        #expect(schedule.isActive(at: now), "Re-enabled schedule should be active")
    }

    @Test("Schedule boundary conditions")
    func scheduleBoundaries() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        let schedule = Schedule(name: "Hour", days: [1,2,3,4,5,6,7], startTime: start, endTime: end)
        
        // Exact start (inclusive)
        let exactStart = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        #expect(schedule.isActive(at: exactStart))
        
        // Exact end (exclusive)
        let exactEnd = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        #expect(!schedule.isActive(at: exactEnd))
        
        // One minute before end
        let almostEnd = calendar.date(from: DateComponents(hour: 9, minute: 59))!
        #expect(schedule.isActive(at: almostEnd))
    }

    @Test("Default schedule properties")
    func defaultSchedule() {
        let schedule = Schedule.defaultSchedule()
        #expect(schedule.name == "Work Hours")
        #expect(schedule.days.count == 5) // Mon-Fri
        #expect(schedule.isEnabled == true)
        #expect(schedule.type == .focus)
    }

    @Test("Schedule display strings formatting")
    func displayStrings() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 17, minute: 0))!
        
        let schedule = Schedule(
            name: "Work",
            days: [2, 4, 6], // Mon, Wed, Fri
            startTime: start,
            endTime: end
        )
        
        // Verify days string
        #expect(schedule.daysString == "Mon, Wed, Fri")
        
        // Verify time range (casing/format depends on locale, but we check structure)
        let timeRange = schedule.timeRangeString
        #expect(timeRange.contains(" - "))
        #expect(timeRange.count > 10)
    }

    @Test("Negative: Schedule with no days should never be active")
    func scheduleNoDays() {
        let now = Date()
        let schedule = Schedule(name: "Empty", days: [], startTime: now.addingTimeInterval(-3600), endTime: now.addingTimeInterval(3600))
        #expect(!schedule.isActive(at: now))
    }

    @Test("Negative: Zero duration schedule should not be active")
    func scheduleZeroDuration() {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: now)
        let time = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        
        let schedule = Schedule(name: "Instant", days: [today], startTime: time, endTime: time)
        #expect(!schedule.isActive(at: time))
    }
}
