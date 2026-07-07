import Foundation

final class AppStateTimerCoordinator {
    private let timerScheduler: any RepeatingTimerScheduling
    private let timerLock = NSLock()
    private var pauseTimer: (any RepeatingTimer)?
    private var pomodoroTimer: (any RepeatingTimer)?
    private var scheduleTimer: (any RepeatingTimer)?
    private var focusStatsTimer: (any RepeatingTimer)?

    init(timerScheduler: any RepeatingTimerScheduling) {
        self.timerScheduler = timerScheduler
    }

    func scheduledRepeatingTimer(
        withTimeInterval interval: TimeInterval,
        _ block: @escaping () -> Void
    ) -> any RepeatingTimer {
        timerScheduler.scheduledRepeatingTimer(withTimeInterval: interval, block)
    }

    func replacePauseTimer(with newTimer: (any RepeatingTimer)?) {
        replaceTimer(
            currentTimer: &pauseTimer,
            newTimer: newTimer
        )
    }

    func replacePomodoroTimer(with newTimer: (any RepeatingTimer)?) {
        replaceTimer(
            currentTimer: &pomodoroTimer,
            newTimer: newTimer
        )
    }

    func replaceScheduleTimer(with newTimer: (any RepeatingTimer)?) {
        replaceTimer(
            currentTimer: &scheduleTimer,
            newTimer: newTimer
        )
    }

    func replaceFocusStatsTimer(with newTimer: (any RepeatingTimer)?) {
        replaceTimer(
            currentTimer: &focusStatsTimer,
            newTimer: newTimer
        )
    }

    func invalidateAllTimers() {
        replacePauseTimer(with: nil)
        replacePomodoroTimer(with: nil)
        replaceScheduleTimer(with: nil)
        replaceFocusStatsTimer(with: nil)
    }

    private func replaceTimer(
        currentTimer: inout (any RepeatingTimer)?,
        newTimer: (any RepeatingTimer)?
    ) {
        timerLock.lock()
        let oldTimer = currentTimer
        currentTimer = newTimer
        timerLock.unlock()
        oldTimer?.invalidate()
    }
}
