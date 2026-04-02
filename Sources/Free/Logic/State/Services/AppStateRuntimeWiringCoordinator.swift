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
        let calendarCancellable = calendarProvider.objectWillChange.sink { _ in
            dispatchToMain(onCalendarChange)
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
        timerCoordinator: AppStateTimerCoordinator,
        calendarCancellable: inout AnyCancellable?
    ) {
        timerCoordinator.invalidateAllTimers()
        calendarCancellable?.cancel()
        calendarCancellable = nil
    }
}
