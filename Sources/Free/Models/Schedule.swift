import Foundation

enum ScheduleType: String, Codable, CaseIterable {
    case focus = "Focus"
    case unfocus = "Break"
}

struct Schedule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var days: Set<Int>  // 1 = Sunday, 7 = Saturday
    var date: Date?  // If set, this is a one-off session for this specific calendar day
    var startTime: Date  // Only time component matters
    var endTime: Date  // Only time component matters
    var isEnabled: Bool = true
    var colorIndex: Int = 0
    var type: ScheduleType = .focus
    var ruleSetId: UUID? = nil

    static func defaultSchedule() -> Schedule {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let endDate = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now)!

        return Schedule(
            name: "Work Hours",
            days: [2, 3, 4, 5, 6],  // Mon-Fri
            startTime: startDate,
            endTime: endDate
        )
    }

    func isActive(at dateToCheck: Date = Date()) -> Bool {
        guard isEnabled else { return false }
        let calendar = Calendar.current
        let startMinutes = Self.minutesSinceMidnight(for: startTime, calendar: calendar)
        let endMinutes = Self.minutesSinceMidnight(for: endTime, calendar: calendar)
        let isOvernight = startMinutes > endMinutes

        if let specificDate = date {
            guard
                let interval = Self.anchoredInterval(
                    anchorDay: calendar.startOfDay(for: specificDate),
                    startMinutes: startMinutes,
                    endMinutes: endMinutes,
                    calendar: calendar
                )
            else {
                return false
            }
            return Self.contains(dateToCheck, in: interval)
        }

        let today = calendar.startOfDay(for: dateToCheck)
        var anchors = [today]
        if isOvernight, let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            anchors.append(yesterday)
        }

        for anchor in anchors {
            let weekday = calendar.component(.weekday, from: anchor)
            guard days.contains(weekday) else { continue }
            guard
                let interval = Self.anchoredInterval(
                    anchorDay: anchor,
                    startMinutes: startMinutes,
                    endMinutes: endMinutes,
                    calendar: calendar
                )
            else {
                continue
            }
            if Self.contains(dateToCheck, in: interval) {
                return true
            }
        }

        return false
    }

    static func minutesSinceMidnight(for date: Date, calendar: Calendar = .current) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour * 60 + minute
    }

    static func anchoredInterval(
        anchorDay: Date,
        startMinutes: Int,
        endMinutes: Int,
        calendar: Calendar = .current
    ) -> DateInterval? {
        let startOfAnchor = calendar.startOfDay(for: anchorDay)
        let start = startOfAnchor.addingTimeInterval(Double(startMinutes) * 60)
        let sameDayEnd = startOfAnchor.addingTimeInterval(Double(endMinutes) * 60)

        let end: Date
        if endMinutes < startMinutes {
            end = sameDayEnd.addingTimeInterval(24 * 60 * 60)
        } else {
            end = sameDayEnd
        }

        guard start < end else { return nil }
        return DateInterval(start: start, end: end)
    }

    static func contains(_ date: Date, in interval: DateInterval) -> Bool {
        interval.start <= date && date < interval.end
    }

    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }

    var daysString: String {
        if let specificDate = date {
            let f = DateFormatter()
            f.dateStyle = .medium
            return f.string(from: specificDate)
        }
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.sorted().map { dayNames[$0 - 1] }.joined(separator: ", ")
    }

    static func calculateOneOffDate(initialDay: Int?, weekOffset: Int, weekStartsOnMonday: Bool)
        -> Date?
    {
        let calendar = Calendar.current
        let targetWeekday = initialDay ?? calendar.component(.weekday, from: Date())
        let weekRange = WeekDateCalculator.getWeekDates(
            weekStartsOnMonday: weekStartsOnMonday, offset: weekOffset)
        return weekRange.first { calendar.component(.weekday, from: $0) == targetWeekday }
    }
}
