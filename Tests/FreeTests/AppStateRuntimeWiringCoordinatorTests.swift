import Combine
import Foundation
import Testing

@testable import FreeLogic

struct AppStateRuntimeWiringCoordinatorTests {
    @Test("resolveMonitor prefers injected monitor and skips builder")
    func resolveMonitorPrefersInjected() {
        let appState = AppState(isTesting: true)
        let injected = BrowserMonitor(appState: appState, server: nil, startTimer: false)
        var buildCallCount = 0

        let resolved = AppStateRuntimeWiringCoordinator.resolveMonitor(
            injectedMonitor: injected,
            isTesting: false
        ) {
            buildCallCount += 1
            return BrowserMonitor(appState: appState, server: nil, startTimer: false)
        }

        #expect(resolved === injected)
        #expect(buildCallCount == 0)
    }

    @Test("resolveMonitor returns nil in testing mode when no monitor is injected")
    func resolveMonitorSkipsBuilderInTesting() {
        var buildCallCount = 0

        let resolved = AppStateRuntimeWiringCoordinator.resolveMonitor(
            injectedMonitor: nil,
            isTesting: true
        ) {
            buildCallCount += 1
            return BrowserMonitor(appState: AppState(isTesting: true), server: nil, startTimer: false)
        }

        #expect(resolved == nil)
        #expect(buildCallCount == 0)
    }

    @Test("start wires schedule timer and calendar subscription; teardown cancels both")
    func startAndTeardown() {
        let calendar = MockCalendarManager()
        let scheduler = MockRepeatingTimerScheduler()
        let timerCoordinator = AppStateTimerCoordinator(timerScheduler: scheduler)
        var calendarChangeCount = 0
        var scheduleTickCount = 0

        var cancellable: AnyCancellable? = AppStateRuntimeWiringCoordinator.start(
            calendarProvider: calendar,
            timerCoordinator: timerCoordinator,
            onCalendarChange: { calendarChangeCount += 1 },
            onScheduleTick: { scheduleTickCount += 1 },
            dispatchToMain: { $0() }
        )

        #expect(scheduler.intervals == [60])
        scheduler.fire(at: 0)
        #expect(scheduleTickCount == 1)

        calendar.events = [
            ExternalEvent(
                id: "event",
                title: "Meeting",
                startDate: Date(),
                endDate: Date().addingTimeInterval(60)
            )
        ]
        #expect(calendarChangeCount == 1)

        AppStateRuntimeWiringCoordinator.teardown(
            timerCoordinator: timerCoordinator,
            calendarCancellable: &cancellable
        )
        #expect(cancellable == nil)
        #expect(scheduler.timers.first?.invalidateCallCount == 1)

        calendar.events = []
        #expect(calendarChangeCount == 1)
    }
}
