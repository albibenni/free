import Foundation

enum ScheduleType: String, Codable, CaseIterable {
    case focus = "Focus"
    case unfocus = "Break"
}

struct Schedule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var days: Set<Int> // 1 = Sunday, 7 = Saturday
    var date: Date? // If set, this is a one-off session for this specific calendar day
    var startTime: Date // Only time component matters
    var endTime: Date   // Only time component matters
    var isEnabled: Bool = true
    var colorIndex: Int = 0
    var type: ScheduleType = .focus
    var ruleSetId: UUID? = nil

    static func defaultSchedule() -> Schedule {
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.hour = 9
        startComponents.minute = 0
        let startDate = calendar.date(from: startComponents) ?? Date()
        
        var endComponents = DateComponents()
        endComponents.hour = 17
        endComponents.minute = 0
        let endDate = calendar.date(from: endComponents) ?? Date()
        
        return Schedule(
            name: "Work Hours",
            days: [2, 3, 4, 5, 6], // Mon-Fri
            startTime: startDate,
            endTime: endDate
        )
    }
    
    func isActive(at dateToCheck: Date = Date()) -> Bool {
        guard isEnabled else { return false }
        
        let calendar = Calendar.current
        
        // 1. Date Check (One-off vs Recurring)
        if let specificDate = date {
            guard calendar.isDate(specificDate, inSameDayAs: dateToCheck) else { return false }
        } else {
            let weekday = calendar.component(.weekday, from: dateToCheck)
            guard days.contains(weekday) else { return false }
        }
        
        // 2. Time Check
        let currentComponents = calendar.dateComponents([.hour, .minute], from: dateToCheck)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        guard let currentMinutes = currentComponents.hour.map({ $0 * 60 + (currentComponents.minute ?? 0) }),
              let startMinutes = startComponents.hour.map({ $0 * 60 + (startComponents.minute ?? 0) }),
              let endMinutes = endComponents.hour.map({ $0 * 60 + (endComponents.minute ?? 0) }) else {
            return false
        }
        
        if startMinutes <= endMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            // Overnights (e.g. 10 PM to 2 AM)
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
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

    static func calculateOneOffDate(initialDay: Int?, weekOffset: Int, weekStartsOnMonday: Bool) -> Date? {
        let calendar = Calendar.current
        let targetWeekday = initialDay ?? calendar.component(.weekday, from: Date())
        let weekRange = WeeklyCalendarView.getWeekDates(weekStartsOnMonday: weekStartsOnMonday, offset: weekOffset)
        return weekRange.first { calendar.component(.weekday, from: $0) == targetWeekday }
    }
}
