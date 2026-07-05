import Foundation

struct ExternalEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    
    func isActive(at now: Date = Date()) -> Bool {
        // Half-open interval, matching Schedule.contains, so an event ending at
        // the same instant another begins never yields two active intervals.
        return now >= startDate && now < endDate
    }
}
