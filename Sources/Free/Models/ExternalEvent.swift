import Foundation

struct ExternalEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    
    func isActive(at now: Date = Date()) -> Bool {
        // Inclusive end (unlike Schedule.contains): zero-duration imported events
        // must count as active at their instant.
        return now >= startDate && now <= endDate
    }
}
