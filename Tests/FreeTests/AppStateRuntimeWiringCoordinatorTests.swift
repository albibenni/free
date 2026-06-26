import Combine
import Foundation
import Testing

@testable import FreeLogic

@MainActor
struct AppStateRuntimeWiringCoordinatorTests {
    private func makeMonitor(startTimer: Bool = false) -> BrowserMonitor {
        BrowserMonitor(
            stateSnapshotProvider: {
                BrowserMonitor.StateSnapshot(
                    isBlocking: false,
                    isPaused: false,
                    blockNewTabs: false,
                    blockDeveloperHosts: false,
                    blockLocalNetworkHosts: false,
                    allowedRules: []
                )
            },
            onEvent: { _ in },
            server: nil,
            startTimer: startTimer
        )
    }

    @Test("resolveMonitor prefers injected monitor and skips builder")
    func resolveMonitorPrefersInjected() async throws {
        let injected = makeMonitor()
        var buildCallCount = 0

        let resolved = AppStateRuntimeWiringCoordinator.resolveMonitor(
            injectedMonitor: injected,
            isTesting: false
        ) {
            buildCallCount += 1
            return makeMonitor()
        }

        #expect(resolved === injected)
        #expect(buildCallCount == 0)
    }

    @Test("resolveMonitor returns nil in testing mode when no monitor is injected")
    func resolveMonitorSkipsBuilderInTesting() async throws {
        var buildCallCount = 0

        let resolved = AppStateRuntimeWiringCoordinator.resolveMonitor(
            injectedMonitor: nil,
            isTesting: true
        ) {
            buildCallCount += 1
            return makeMonitor()
        }

        #expect(resolved == nil)
        #expect(buildCallCount == 0)
    }

    @Test("start wires schedule timer and calendar subscription; teardown cancels both")
    func startAndTeardown() async throws {
        let calendar = MockCalendarManager()
        let scheduler = MockRepeatingTimerScheduler()
        let timerCoordinator = AppStateTimerCoordinator(timerScheduler: scheduler)
        var calendarChangeCount = 0
        var scheduleTickCount = 0

        let startResult = AppStateRuntimeWiringCoordinator.start(
            calendarProvider: calendar,
            timerCoordinator: timerCoordinator,
            onCalendarChange: { calendarChangeCount += 1 },
            onScheduleTick: { scheduleTickCount += 1 },
            scheduleTickIntervalProvider: { 600 },
            dispatchToMain: { $0() }
        )

        #expect(scheduler.intervals == [600])
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
            timerCoordinator: timerCoordinator
        )
        #expect(scheduler.timers.first?.invalidateCallCount == 1)

        startResult.calendarCancellable.cancel()

        calendar.events = []
        #expect(calendarChangeCount == 1)
    }
}
