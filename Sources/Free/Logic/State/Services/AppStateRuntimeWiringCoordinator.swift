import Combine
import Foundation

enum AppStateRuntimeWiringCoordinator {
    struct StartResult {
        let calendarCancellable: AnyCancellable
        let rescheduleScheduleTimer: @MainActor () -> Void
    }

    static func resolveMonitor(
        injectedMonitor: BrowserMonitor?,
        isTesting: Bool,
        startBrowserMonitor: Bool = true,
        buildMonitor: () -> BrowserMonitor
    ) -> BrowserMonitor? {
        if let injectedMonitor {
            return injectedMonitor
        }
        // v2 (App Store) disables the AppleScript engine — the content-filter
        // extension enforces blocking instead.
        guard !isTesting, startBrowserMonitor else { return nil }
        return buildMonitor()
    }

    // Cancellation must be callable from nonisolated contexts (AnyCancellable can
    // fire from a deinit), so the flag lives behind a lock rather than on the actor.
    private final class CancellableState: @unchecked Sendable {
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

    // @MainActor class: implicitly Sendable, so it can re-arm itself from
    // withObservationTracking's @Sendable onChange while holding the
    // non-Sendable calendar provider safely on the main actor.
    @MainActor
    private final class CalendarObservationTracker {
        private let calendarProvider: any CalendarProvider
        private let onCalendarChange: @MainActor () -> Void
        private let dispatchToMain: @Sendable (@escaping @Sendable () -> Void) -> Void
        private let state: CancellableState

        init(
            calendarProvider: any CalendarProvider,
            onCalendarChange: @escaping @MainActor () -> Void,
            dispatchToMain: @escaping @Sendable (@escaping @Sendable () -> Void) -> Void,
            state: CancellableState
        ) {
            self.calendarProvider = calendarProvider
            self.onCalendarChange = onCalendarChange
            self.dispatchToMain = dispatchToMain
            self.state = state
        }

        func startTracking() {
            guard !state.isCancelled else { return }
            withObservationTracking {
                _ = calendarProvider.events
            } onChange: { [self] in
                dispatchToMain {
                    // The seam contract is main-queue delivery.
                    MainActor.assumeIsolated {
                        guard !self.state.isCancelled else { return }
                        self.onCalendarChange()
                        self.startTracking()
                    }
                }
            }
        }
    }

    @MainActor
    static func start(
        calendarProvider: any CalendarProvider,
        timerCoordinator: AppStateTimerCoordinator,
        onCalendarChange: @escaping @MainActor () -> Void,
        onScheduleTick: @escaping @MainActor () -> Void,
        scheduleTickIntervalProvider: @escaping @MainActor () -> TimeInterval,
        dispatchToMain: @escaping @Sendable (@escaping @Sendable () -> Void) -> Void = { block in
            DispatchQueue.main.async(execute: block)
        }
    ) -> StartResult {
        let state = CancellableState()
        CalendarObservationTracker(
            calendarProvider: calendarProvider,
            onCalendarChange: onCalendarChange,
            dispatchToMain: dispatchToMain,
            state: state
        ).startTracking()
        let calendarCancellable = AnyCancellable {
            state.cancel()
        }

        @MainActor func armScheduleTimer() {
            let interval = max(1, scheduleTickIntervalProvider())
            let timer = timerCoordinator.scheduledRepeatingTimer(withTimeInterval: interval) {
                // The production scheduler delivers on the main queue.
                MainActor.assumeIsolated {
                    onScheduleTick()
                    armScheduleTimer()
                }
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
