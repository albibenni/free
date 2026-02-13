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
}
