import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct AppStateScheduleTickCoordinatorTests {
    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? .distantPast
    }

    @Test("nextInterval targets the nearest upcoming schedule boundary")
    func nextIntervalTargetsNearestScheduleBoundary() async throws {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 4, day: 2, hour: 10, minute: 0, calendar: calendar)
        let weekday = calendar.component(.weekday, from: now)
        let start = makeDate(year: 2026, month: 4, day: 2, hour: 10, minute: 5, calendar: calendar)
        let end = makeDate(year: 2026, month: 4, day: 2, hour: 11, minute: 0, calendar: calendar)

        let schedule = Schedule(
            name: "Focus",
            days: [weekday],
            startTime: start,
            endTime: end,
            isEnabled: true,
            type: .focus
        )

        let interval = AppStateScheduleTickCoordinator.nextInterval(
            schedules: [schedule],
            calendarEvents: [],
            calendarIntegrationEnabled: false,
            isStrict: false,
            now: now,
            calendar: calendar
        )

        #expect(interval == 300)
    }

    @Test("nextInterval uses event boundaries when meetings can override blocking")
    func nextIntervalTracksMeetingBoundariesWhenEnabled() async throws {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 4, day: 2, hour: 10, minute: 0, calendar: calendar)
        let event = ExternalEvent(
            id: "meeting",
            title: "Meeting",
            startDate: now.addingTimeInterval(120),
            endDate: now.addingTimeInterval(900)
        )

        let interval = AppStateScheduleTickCoordinator.nextInterval(
            schedules: [],
            calendarEvents: [event],
            calendarIntegrationEnabled: true,
            isStrict: false,
            now: now,
            calendar: calendar
        )

        #expect(interval == 120)
    }

    @Test("nextInterval ignores meeting boundaries when strict mode is active")
    func nextIntervalIgnoresMeetingBoundariesInStrictMode() async throws {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 4, day: 2, hour: 10, minute: 0, calendar: calendar)
        let event = ExternalEvent(
            id: "meeting",
            title: "Meeting",
            startDate: now.addingTimeInterval(120),
            endDate: now.addingTimeInterval(900)
        )

        let interval = AppStateScheduleTickCoordinator.nextInterval(
            schedules: [],
            calendarEvents: [event],
            calendarIntegrationEnabled: true,
            isStrict: true,
            now: now,
            calendar: calendar
        )

        #expect(interval == 900)
    }
}
