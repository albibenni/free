import Testing
import Foundation
@testable import FreeLogic

struct ScheduleTests {
    @Test("anchoredInterval builds same-day and overnight ranges")
    func anchoredIntervalConstruction() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 2, day: 16))!

        let dayInterval = Schedule.anchoredInterval(
            anchorDay: anchor,
            startMinutes: 9 * 60,
            endMinutes: 10 * 60,
            calendar: calendar
        )
        #expect(dayInterval != nil)
        #expect(calendar.component(.day, from: dayInterval!.start) == 16)
        #expect(calendar.component(.day, from: dayInterval!.end) == 16)

        let overnightInterval = Schedule.anchoredInterval(
            anchorDay: anchor,
            startMinutes: 22 * 60,
            endMinutes: 2 * 60,
            calendar: calendar
        )
        #expect(overnightInterval != nil)
        #expect(calendar.component(.day, from: overnightInterval!.start) == 16)
        #expect(calendar.component(.day, from: overnightInterval!.end) == 17)
    }

    @Test("anchoredInterval rejects zero-duration ranges")
    func anchoredIntervalZeroDuration() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 2, day: 16))!

        let zero = Schedule.anchoredInterval(
            anchorDay: anchor,
            startMinutes: 10 * 60,
            endMinutes: 10 * 60,
            calendar: calendar
        )
        #expect(zero == nil)
    }

    @Test("Schedule.contains uses inclusive-start exclusive-end semantics")
    func intervalContainsSemantics() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 2, day: 16))!
        let interval = Schedule.anchoredInterval(
            anchorDay: anchor,
            startMinutes: 9 * 60,
            endMinutes: 10 * 60,
            calendar: calendar
        )!
        let atStart = calendar.date(from: DateComponents(year: 2026, month: 2, day: 16, hour: 9, minute: 0))!
        let atEnd = calendar.date(from: DateComponents(year: 2026, month: 2, day: 16, hour: 10, minute: 0))!

        #expect(Schedule.contains(atStart, in: interval))
        #expect(!Schedule.contains(atEnd, in: interval))
    }

    @Test("anchoredInterval normalizes anchorDay to start-of-day")
    func anchoredIntervalAnchorNormalization() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        // Anchor includes time; interval should still be based on that calendar day.
        let noisyAnchor = calendar.date(from: DateComponents(year: 2026, month: 2, day: 16, hour: 18, minute: 45))!
        let interval = Schedule.anchoredInterval(
            anchorDay: noisyAnchor,
            startMinutes: 9 * 60,
            endMinutes: 10 * 60,
            calendar: calendar
        )
        #expect(interval != nil)
        #expect(calendar.component(.hour, from: interval!.start) == 9)
        #expect(calendar.component(.minute, from: interval!.start) == 0)
        #expect(calendar.component(.hour, from: interval!.end) == 10)
        #expect(calendar.component(.minute, from: interval!.end) == 0)
    }

    @Test("Recurring overnight schedule carries correctly across week boundary")
    func recurringOvernightWeekBoundary() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 22, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 2, minute: 0))!
        // Saturday session.
        let schedule = Schedule(name: "Weekend Night", days: [7], startTime: start, endTime: end)

        // Saturday 23:30 should be active.
        let saturdayLate = calendar.date(from: DateComponents(year: 2023, month: 1, day: 7, hour: 23, minute: 30))!
        // Sunday 01:30 should still be active (carry from Saturday).
        let sundayEarly = calendar.date(from: DateComponents(year: 2023, month: 1, day: 8, hour: 1, minute: 30))!
        // Sunday 03:00 should be inactive (past end).
        let sundayAfter = calendar.date(from: DateComponents(year: 2023, month: 1, day: 8, hour: 3, minute: 0))!

        #expect(schedule.isActive(at: saturdayLate))
        #expect(schedule.isActive(at: sundayEarly))
        #expect(!schedule.isActive(at: sundayAfter))
    }

    @Test("One-off overnight schedule has exclusive end on the next day")
    func oneOffOvernightBoundary() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: 22, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 2, minute: 0))!
        let oneOffDay = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2))! // Monday
        let schedule = Schedule(name: "One Night", days: [], date: oneOffDay, startTime: start, endTime: end)

        let mondayNight = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2, hour: 22, minute: 0))!
        let tuesdayBeforeEnd = calendar.date(from: DateComponents(year: 2023, month: 1, day: 3, hour: 1, minute: 59))!
        let tuesdayAtEnd = calendar.date(from: DateComponents(year: 2023, month: 1, day: 3, hour: 2, minute: 0))!

        #expect(schedule.isActive(at: mondayNight))
        #expect(schedule.isActive(at: tuesdayBeforeEnd))
        #expect(!schedule.isActive(at: tuesdayAtEnd))
    }
    
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
        // Tuesday 01:00 (Should be active as continuation of Monday overnight session)
        let tuesdayEarlyMorning = calendar.date(from: DateComponents(year: 2023, month: 1, day: 3, hour: 1, minute: 0))!
        // Monday 01:00 (Should be inactive because it belongs to Sunday's overnight session)
        let mondayEarlyMorning = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2, hour: 1, minute: 0))!
        // Monday 12:00 (Should be inactive)
        let mondayNoon = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2, hour: 12, minute: 0))!
        
        // Then
        #expect(schedule.isActive(at: mondayNight), "Should be active at 23:00")
        #expect(schedule.isActive(at: tuesdayEarlyMorning), "Should be active Tuesday at 01:00")
        #expect(!schedule.isActive(at: mondayEarlyMorning), "Should be inactive Monday at 01:00")
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

    @Test("Schedule daysString with various day counts")
    func daysStringVariations() {
        // Single day
        let s1 = Schedule(name: "S", days: [1], startTime: Date(), endTime: Date())
        #expect(s1.daysString == "Sun")
        
        // All days
        let s2 = Schedule(name: "A", days: [1,2,3,4,5,6,7], startTime: Date(), endTime: Date())
        #expect(s2.daysString == "Sun, Mon, Tue, Wed, Thu, Fri, Sat")
        
        // Non-sequential
        let s3 = Schedule(name: "N", days: [1, 7], startTime: Date(), endTime: Date())
        #expect(s3.daysString == "Sun, Sat")
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

    @Test("Negative: One-off zero duration schedule should not be active")
    func oneOffZeroDuration() {
        let calendar = Calendar.current
        let oneOffDate = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2))!
        let time = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        let schedule = Schedule(name: "OneOffInstant", days: [], date: oneOffDate, startTime: time, endTime: time)

        let check = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2, hour: 10, minute: 0))!
        #expect(!schedule.isActive(at: check))
    }

    @Test("One-off schedule logic")
    func oneOffScheduleLogic() {
        let calendar = Calendar.current
        // Create a date for "Today" and "Tomorrow"
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let start = calendar.date(from: DateComponents(hour: 10, minute: 0))!
        let end = calendar.date(from: DateComponents(hour: 11, minute: 0))!
        
        // Setup: A one-off schedule bonded to TODAY at 10 AM
        let schedule = Schedule(name: "Once", days: [], date: today, startTime: start, endTime: end)
        
        // 1. Should be active today at 10:30 AM
        let testTimeToday = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: today)!
        #expect(schedule.isActive(at: testTimeToday))
        
        // 2. Should NOT be active tomorrow at 10:30 AM (even if weekday matches, date takes precedence)
        let testTimeTomorrow = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: tomorrow)!
        #expect(!schedule.isActive(at: testTimeTomorrow))
        
        // 3. String representation should show date
        #expect(schedule.daysString != "One-off") // It shows medium date style now
        #expect(schedule.daysString.count > 5)
    }

    @Test("calculateOneOffDate correctly maps weekdays across offsets")
    func oneOffDateCalculation() {
        let calendar = Calendar.current
        // A known Monday (Feb 16, 2026)
        let monComps = DateComponents(year: 2026, month: 2, day: 16)
        let mon = calendar.date(from: monComps)!
        
        // 1. Current week (Offset 0), target Wednesday (3)
        // Monday start: Sun=1, Mon=2, Tue=3, Wed=4... wait. 
        // Sunday is always 1 in Calendar components.
        // Feb 16 is Monday (2). Wednesday is Feb 18 (4).
        
        if let wed = Schedule.calculateOneOffDate(initialDay: 4, weekOffset: 0, weekStartsOnMonday: true) {
            #expect(calendar.component(.day, from: wed) == 18)
            #expect(calendar.component(.month, from: wed) == 2)
        } else {
            Issue.record("Failed to calculate date")
        }
        
        // 2. Next week (Offset 1), target Monday (2)
        if let nextMon = Schedule.calculateOneOffDate(initialDay: 2, weekOffset: 1, weekStartsOnMonday: true) {
            #expect(calendar.component(.day, from: nextMon) == 23)
        } else {
            Issue.record("Failed to calculate next week date")
        }

        // 3. Nil initialDay should default to today's weekday
        if let inferred = Schedule.calculateOneOffDate(initialDay: nil, weekOffset: 0, weekStartsOnMonday: false) {
            let todayWeekday = calendar.component(.weekday, from: Date())
            #expect(calendar.component(.weekday, from: inferred) == todayWeekday)
        } else {
            Issue.record("Failed to infer one-off date from current weekday")
        }
    }
}
