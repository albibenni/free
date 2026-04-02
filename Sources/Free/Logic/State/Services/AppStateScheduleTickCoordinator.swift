import Foundation

enum AppStateScheduleTickCoordinator {
    private static let minimumInterval: TimeInterval = 1
    private static let fallbackInterval: TimeInterval = 15 * 60
    private static let maximumInterval: TimeInterval = 60 * 60

    static func nextInterval(
        schedules: [Schedule],
        calendarEvents: [ExternalEvent],
        calendarIntegrationEnabled: Bool,
        isStrict: Bool,
        calendarImportsBlockTime: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimeInterval {
        var upcomingBoundaries = scheduleBoundaries(
            schedules: schedules,
            now: now,
            calendar: calendar
        )

        let shouldTrackMeetingBoundaries =
            calendarIntegrationEnabled
            && !isStrict
            && !calendarImportsBlockTime
        if shouldTrackMeetingBoundaries {
            for event in calendarEvents {
                if event.startDate > now {
                    upcomingBoundaries.append(event.startDate)
                }
                if event.endDate > now {
                    upcomingBoundaries.append(event.endDate)
                }
            }
        }

        guard let nextBoundary = upcomingBoundaries.min() else {
            return fallbackInterval
        }

        let rawInterval = nextBoundary.timeIntervalSince(now)
        let clampedToMaximum = min(rawInterval, maximumInterval)
        return max(minimumInterval, clampedToMaximum)
    }

    private static func scheduleBoundaries(
        schedules: [Schedule],
        now: Date,
        calendar: Calendar
    ) -> [Date] {
        var boundaries: [Date] = []
        let today = calendar.startOfDay(for: now)

        for schedule in schedules where schedule.isEnabled {
            let startMinutes = Schedule.minutesSinceMidnight(for: schedule.startTime, calendar: calendar)
            let endMinutes = Schedule.minutesSinceMidnight(for: schedule.endTime, calendar: calendar)

            if let specificDate = schedule.date {
                let anchor = calendar.startOfDay(for: specificDate)
                appendBoundaries(
                    anchorDay: anchor,
                    startMinutes: startMinutes,
                    endMinutes: endMinutes,
                    now: now,
                    calendar: calendar,
                    to: &boundaries
                )
                continue
            }

            for dayOffset in 0...7 {
                guard
                    let anchor = calendar.date(byAdding: .day, value: dayOffset, to: today)
                else { continue }
                let weekday = calendar.component(.weekday, from: anchor)
                guard schedule.days.contains(weekday) else { continue }
                appendBoundaries(
                    anchorDay: anchor,
                    startMinutes: startMinutes,
                    endMinutes: endMinutes,
                    now: now,
                    calendar: calendar,
                    to: &boundaries
                )
            }
        }

        return boundaries
    }

    private static func appendBoundaries(
        anchorDay: Date,
        startMinutes: Int,
        endMinutes: Int,
        now: Date,
        calendar: Calendar,
        to boundaries: inout [Date]
    ) {
        guard
            let interval = Schedule.anchoredInterval(
                anchorDay: anchorDay,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                calendar: calendar
            )
        else { return }

        if interval.start > now {
            boundaries.append(interval.start)
        }
        if interval.end > now {
            boundaries.append(interval.end)
        }
    }
}
