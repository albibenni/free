import Foundation

protocol RepeatingTimer: Sendable {
    func invalidate()
}

protocol RepeatingTimerScheduling: Sendable {
    func scheduledRepeatingTimer(withTimeInterval interval: TimeInterval, _ block: @escaping () -> Void) -> any RepeatingTimer
}

/// Fires on the main queue regardless of the scheduling thread. `Timer.scheduledTimer`
/// installs on the calling thread's run loop, which never runs on actor executor
/// threads (e.g. `BrowserMonitor`), so such a timer would never fire.
final class DispatchRepeatingTimer: RepeatingTimer, @unchecked Sendable {
    private let source: DispatchSourceTimer

    init(interval: TimeInterval, block: @escaping () -> Void) {
        source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + interval, repeating: interval)
        source.setEventHandler(handler: block)
        source.resume()
    }

    func invalidate() {
        source.cancel()
    }
}

struct DefaultRepeatingTimerScheduler: RepeatingTimerScheduling {
    func scheduledRepeatingTimer(withTimeInterval interval: TimeInterval, _ block: @escaping () -> Void) -> any RepeatingTimer {
        DispatchRepeatingTimer(interval: interval, block: block)
    }
}
