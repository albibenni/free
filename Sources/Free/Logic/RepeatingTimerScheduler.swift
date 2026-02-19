import Foundation

protocol RepeatingTimer {
    func invalidate()
}

extension Timer: RepeatingTimer {}

protocol RepeatingTimerScheduling {
    func scheduledRepeatingTimer(withTimeInterval interval: TimeInterval, _ block: @escaping () -> Void) -> any RepeatingTimer
}

struct DefaultRepeatingTimerScheduler: RepeatingTimerScheduling {
    func scheduledRepeatingTimer(withTimeInterval interval: TimeInterval, _ block: @escaping () -> Void) -> any RepeatingTimer {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in block() }
    }
}
