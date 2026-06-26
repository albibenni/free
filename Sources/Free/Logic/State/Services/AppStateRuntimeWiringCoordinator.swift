import Combine
import Foundation

enum AppStateRuntimeWiringCoordinator {
    struct StartResult {
        let calendarCancellable: AnyCancellable
        let rescheduleScheduleTimer: () -> Void
    }

    static func resolveMonitor(
        injectedMonitor: BrowserMonitor?,
        isTesting: Bool,
        buildMonitor: () -> BrowserMonitor
    ) -> BrowserMonitor? {
        if let injectedMonitor {
            return injectedMonitor
        }
        guard !isTesting else { return nil }
        return buildMonitor()
    }

    static func start(
        calendarProvider: any CalendarProvider,
        timerCoordinator: AppStateTimerCoordinator,
        onCalendarChange: @escaping () -> Void,
        onScheduleTick: @escaping () -> Void,
        scheduleTickIntervalProvider: @escaping () -> TimeInterval,
        dispatchToMain: @escaping (@escaping () -> Void) -> Void = { block in
            DispatchQueue.main.async(execute: block)
        }
    ) -> StartResult {
        // Observe calendar provider events
        final class CancellableState: @unchecked Sendable {
            private let lock = NSLock()
            private var _isCancelled = false
            var isCancelled: Bool {
                lock.lock(); defer { lock.unlock() }
                return _isCancelled
            }
            func cancel() {
                lock.lock(); defer { lock.unlock() }
                _isCancelled = true
            }
        }
        let state = CancellableState()
        
        @Sendable func observeCalendar() {
            guard !state.isCancelled else { return }
            withObservationTracking {
                _ = calendarProvider.events
            } onChange: {
                dispatchToMain {
                    guard !state.isCancelled else { return }
                    onCalendarChange()
                    observeCalendar()
                }
            }
        }
        observeCalendar()
        let calendarCancellable = AnyCancellable {
            state.cancel()
        }

        func armScheduleTimer() {
            let interval = max(1, scheduleTickIntervalProvider())
            let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: interval) {
                onScheduleTick()
                armScheduleTimer()
            }
            timerCoordinator.replaceScheduleTimer(with: timer)
        }

        armScheduleTimer()

        return StartResult(
            calendarCancellable: calendarCancellable,
            rescheduleScheduleTimer: armScheduleTimer
        )
    }

    static func teardown(
        timerCoordinator: AppStateTimerCoordinator
    ) {
        timerCoordinator.invalidateAllTimers()
    }
}
