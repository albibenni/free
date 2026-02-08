import Foundation

struct ExternalEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    
    func isActive(at now: Date = Date()) -> Bool {
        return now >= startDate && now <= endDate
    }
}
