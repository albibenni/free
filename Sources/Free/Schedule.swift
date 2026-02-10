import Foundation

enum ScheduleType: String, Codable, CaseIterable {
    case focus = "Focus"
    case unfocus = "Break"
}

struct Schedule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var days: Set<Int> // 1 = Sunday, 7 = Saturday (matching Calendar.component(.weekday, ...))
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
    
    func isActive(at date: Date = Date()) -> Bool {
        guard isEnabled else { return false }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        guard days.contains(weekday) else { return false }
        
        let currentComponents = calendar.dateComponents([.hour, .minute], from: date)
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
}
