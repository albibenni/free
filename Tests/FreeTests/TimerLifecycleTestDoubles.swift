import Foundation
@testable import FreeLogic

final class MockRepeatingTimer: RepeatingTimer {
    private(set) var invalidateCallCount = 0

    func invalidate() {
        invalidateCallCount += 1
    }
}

final class MockRepeatingTimerScheduler: RepeatingTimerScheduling {
    private(set) var intervals: [TimeInterval] = []
    private(set) var timers: [MockRepeatingTimer] = []
    private(set) var handlers: [() -> Void] = []

    func scheduledRepeatingTimer(withTimeInterval interval: TimeInterval, _ block: @escaping () -> Void) -> any RepeatingTimer {
        intervals.append(interval)
        handlers.append(block)
        let timer = MockRepeatingTimer()
        timers.append(timer)
        return timer
    }

    func fire(at index: Int) {
        handlers[index]()
    }
}
