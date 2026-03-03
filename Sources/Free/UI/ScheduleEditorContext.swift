import Foundation

struct ScheduleEditorContext: Identifiable {
    let id = UUID()
    var day: Int?
    var startTime: Date?
    var endTime: Date?
    var schedule: Schedule?
    var weekOffset: Int = 0
}
