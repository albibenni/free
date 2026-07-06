import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct RepeatingTimerSchedulerTests {
    @Test("DefaultRepeatingTimerScheduler schedules a live repeating timer")
    @MainActor
    func defaultSchedulerSchedulesTimer() async throws {
        let scheduler = DefaultRepeatingTimerScheduler()
        let interval: TimeInterval = 0.01
        var fireCount = 0

        let timer = scheduler.scheduledRepeatingTimer(withTimeInterval: interval) {
            fireCount += 1
        }

        try await Task.sleep(nanoseconds: 60_000_000)
        timer.invalidate()
        #expect(fireCount > 0)
    }
}
