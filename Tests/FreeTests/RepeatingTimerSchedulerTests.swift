import Foundation
import Testing

@testable import FreeLogic

struct RepeatingTimerSchedulerTests {
    @Test("DefaultRepeatingTimerScheduler schedules a live repeating timer")
    @MainActor
    func defaultSchedulerSchedulesTimer() {
        let scheduler = DefaultRepeatingTimerScheduler()
        let interval: TimeInterval = 0.01
        var fireCount = 0

        let timer = scheduler.scheduledRepeatingTimer(withTimeInterval: interval) {
            fireCount += 1
        }

        RunLoop.current.run(until: Date().addingTimeInterval(0.06))
        timer.invalidate()
        #expect(fireCount > 0)
    }
}
