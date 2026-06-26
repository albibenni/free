import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct AAAWeeklyCalendarSupportBootstrapTests {
    @Test("Weekly calendar default date builder returns date for hour/minute components")
    func weeklyCalendarDefaultDateBuilderBootstrapPath() async throws {
        let calendar = Calendar.current
        let built = WeeklyCalendarSupport.calendarDateBuilder(
            calendar,
            DateComponents(hour: 9, minute: 30)
        )
        #expect(built != nil)
    }
}
