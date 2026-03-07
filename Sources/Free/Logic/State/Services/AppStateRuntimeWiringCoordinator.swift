import Combine
import Foundation

enum AppStateRuntimeWiringCoordinator {
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
        dispatchToMain: @escaping (@escaping () -> Void) -> Void = { block in
            DispatchQueue.main.async(execute: block)
        }
    ) -> AnyCancellable {
        let calendarCancellable = calendarProvider.objectWillChange.sink { _ in
            dispatchToMain(onCalendarChange)
        }

        let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: 60, onScheduleTick)
        timerCoordinator.replaceScheduleTimer(with: timer)
        return calendarCancellable
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
