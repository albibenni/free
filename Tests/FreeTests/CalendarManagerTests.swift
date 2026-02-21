import Combine
import Foundation
import Testing

@testable import FreeLogic

private final class CalendarRuntimeState {
    var hasAuthorization = false
    var accessRequests: [((Bool) -> Void)] = []
    var loadedRanges: [DateInterval] = []
    var snapshots: [CalendarEventSnapshot] = []
    var dispatchCalls = 0

    func makeRuntime() -> CalendarManagerRuntime {
        CalendarManagerRuntime(
            hasEventAuthorization: { [weak self] in
                self?.hasAuthorization ?? false
            },
            requestEventAccess: { [weak self] completion in
                self?.accessRequests.append(completion)
            },
            loadEvents: { [weak self] start, end in
                guard let self else { return [] }
                self.loadedRanges.append(DateInterval(start: start, end: end))
                return self.snapshots
            },
            dispatchMain: { [weak self] work in
                self?.dispatchCalls += 1
                work()
            }
        )
    }
}

@Suite(.serialized)
struct CalendarManagerTests {

    private func isolatedAppState(name: String, calendar: any CalendarProvider) -> AppState {
        let suite = "CalendarManagerTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, calendar: calendar, isTesting: true)
    }

    @Test("MockCalendarManager allows manual event injection and no-op methods")
    func mockCalendarLogic() {
        let mock = MockCalendarManager()
        let now = Date()
        let event = ExternalEvent(
            id: "1", title: "Test", startDate: now, endDate: now.addingTimeInterval(3600))

        mock.requestAccess()
        mock.fetchEvents()
        mock.events = [event]

        #expect(mock.events.count == 1)
        #expect(mock.events.first?.title == "Test")
        #expect(mock.isAuthorized == true)
    }

    @Test("RealCalendarManager init without authorization sets up refresh timer only")
    func initUnauthorizedPath() {
        let runtimeState = CalendarRuntimeState()
        runtimeState.hasAuthorization = false
        let scheduler = MockRepeatingTimerScheduler()
        let manager = RealCalendarManager(
            timerScheduler: scheduler,
            runtime: runtimeState.makeRuntime(),
            nowProvider: Date.init
        )

        #expect(manager.isAuthorized == false)
        #expect(runtimeState.loadedRanges.isEmpty)
        #expect(runtimeState.dispatchCalls == 0)
        #expect(scheduler.intervals == [300.0])

        scheduler.fire(at: 0)
        #expect(runtimeState.loadedRanges.isEmpty)
    }

    @Test("RealCalendarManager init accepts Date.init nowProvider path")
    func initWithDateNowProvider() {
        let runtimeState = CalendarRuntimeState()
        runtimeState.hasAuthorization = false
        let scheduler = MockRepeatingTimerScheduler()

        let manager = RealCalendarManager(
            timerScheduler: scheduler,
            runtime: runtimeState.makeRuntime(),
            nowProvider: Date.init
        )

        #expect(manager.isAuthorized == false)
        #expect(scheduler.intervals == [300.0])
    }

    @Test("RealCalendarManager init with authorization performs immediate fetch")
    func initAuthorizedPath() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let runtimeState = CalendarRuntimeState()
        runtimeState.hasAuthorization = true
        runtimeState.snapshots = [
            CalendarEventSnapshot(
                eventIdentifier: "id-1",
                title: "Focus Session",
                startDate: now,
                endDate: now.addingTimeInterval(1800),
                isAllDay: false
            )
        ]

        let manager = RealCalendarManager(
            timerScheduler: MockRepeatingTimerScheduler(),
            runtime: runtimeState.makeRuntime(),
            nowProvider: { now }
        )

        #expect(manager.isAuthorized == true)
        #expect(runtimeState.loadedRanges.count == 1)
        #expect(runtimeState.dispatchCalls == 1)
        #expect(manager.events.count == 1)
        #expect(manager.events[0].title == "Focus Session")

        let calendar = Calendar.current
        let expectedStart = calendar.date(
            byAdding: .day,
            value: -7,
            to: calendar.startOfDay(for: now)
        )!
        let expectedEnd = calendar.date(
            byAdding: .day,
            value: 7,
            to: calendar.startOfDay(for: now)
        )!
        let range = runtimeState.loadedRanges[0]
        #expect(range.start == expectedStart)
        #expect(range.end == expectedEnd)
    }

    @Test("requestAccess denied updates authorization without fetching")
    func requestAccessDenied() {
        let runtimeState = CalendarRuntimeState()
        let manager = RealCalendarManager(
            timerScheduler: MockRepeatingTimerScheduler(),
            runtime: runtimeState.makeRuntime(),
            nowProvider: Date.init
        )

        manager.requestAccess()
        #expect(runtimeState.accessRequests.count == 1)
        runtimeState.accessRequests[0](false)

        #expect(manager.isAuthorized == false)
        #expect(runtimeState.loadedRanges.isEmpty)
        #expect(runtimeState.dispatchCalls == 1)
    }

    @Test("requestAccess granted enables authorization and fetches")
    func requestAccessGranted() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let runtimeState = CalendarRuntimeState()
        runtimeState.snapshots = [
            CalendarEventSnapshot(
                eventIdentifier: "id-2",
                title: "Meeting",
                startDate: now,
                endDate: now.addingTimeInterval(1200),
                isAllDay: false
            )
        ]
        let manager = RealCalendarManager(
            timerScheduler: MockRepeatingTimerScheduler(),
            runtime: runtimeState.makeRuntime(),
            nowProvider: { now }
        )

        manager.requestAccess()
        runtimeState.accessRequests[0](true)

        #expect(manager.isAuthorized == true)
        #expect(runtimeState.loadedRanges.count == 1)
        #expect(manager.events.count == 1)
        #expect(manager.events[0].title == "Meeting")
    }

    @Test("requestAccess callback is ignored if manager was released")
    func requestAccessAfterDeinit() {
        let runtimeState = CalendarRuntimeState()
        var manager: RealCalendarManager? = RealCalendarManager(
            timerScheduler: MockRepeatingTimerScheduler(),
            runtime: runtimeState.makeRuntime(),
            nowProvider: Date.init
        )

        manager?.requestAccess()
        #expect(runtimeState.accessRequests.count == 1)
        manager = nil
        runtimeState.accessRequests[0](true)

        #expect(runtimeState.dispatchCalls == 0)
    }

    @Test("fetchEvents guard prevents work when unauthorized")
    func fetchGuardUnauthorized() {
        let runtimeState = CalendarRuntimeState()
        let manager = RealCalendarManager(
            timerScheduler: MockRepeatingTimerScheduler(),
            runtime: runtimeState.makeRuntime(),
            nowProvider: Date.init
        )

        manager.fetchEvents()
        #expect(runtimeState.loadedRanges.isEmpty)
        #expect(runtimeState.dispatchCalls == 0)
    }

    @Test("fetchEvents maps snapshots, filters all-day, and applies id/title defaults")
    func fetchMappingAndFiltering() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let runtimeState = CalendarRuntimeState()
        runtimeState.snapshots = [
            CalendarEventSnapshot(
                eventIdentifier: "all-day",
                title: "All Day",
                startDate: now,
                endDate: now.addingTimeInterval(3600),
                isAllDay: true
            ),
            CalendarEventSnapshot(
                eventIdentifier: nil,
                title: nil,
                startDate: now.addingTimeInterval(60),
                endDate: now.addingTimeInterval(600),
                isAllDay: false
            ),
            CalendarEventSnapshot(
                eventIdentifier: "custom-id",
                title: "Deep Work",
                startDate: now.addingTimeInterval(120),
                endDate: now.addingTimeInterval(900),
                isAllDay: false
            ),
        ]
        let manager = RealCalendarManager(
            timerScheduler: MockRepeatingTimerScheduler(),
            runtime: runtimeState.makeRuntime(),
            nowProvider: { now }
        )

        manager.isAuthorized = true
        manager.fetchEvents()

        #expect(runtimeState.loadedRanges.count == 1)
        #expect(runtimeState.dispatchCalls == 1)
        #expect(manager.events.count == 2)
        #expect(manager.events[0].title == "Untitled Event")
        #expect(
            manager.events[0].id.hasSuffix(
                "-\(runtimeState.snapshots[1].startDate.timeIntervalSince1970)")
        )
        #expect(manager.events[1].title == "Deep Work")
        #expect(
            manager.events[1].id
                == "custom-id-\(runtimeState.snapshots[2].startDate.timeIntervalSince1970)"
        )
    }

    @Test("refresh timer triggers periodic fetch when authorized")
    func timerDrivenRefresh() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let runtimeState = CalendarRuntimeState()
        let scheduler = MockRepeatingTimerScheduler()
        let manager = RealCalendarManager(
            timerScheduler: scheduler,
            runtime: runtimeState.makeRuntime(),
            nowProvider: { now }
        )
        manager.isAuthorized = true

        scheduler.fire(at: 0)
        #expect(runtimeState.loadedRanges.count == 1)
    }

    @Test("AppState reacts to calendar authorization changes")
    func appStateCalendarAuth() {
        let mock = MockCalendarManager()
        mock.isAuthorized = false

        let appState = isolatedAppState(name: "appStateCalendarAuth", calendar: mock)

        #expect(appState.calendarIntegrationEnabled == false)
        appState.calendarIntegrationEnabled = true
        #expect(appState.calendarIntegrationEnabled == true)
    }

    @Test("AppState re-checks schedules when calendar events change")
    func appStateReactsToEvents() {
        let mock = MockCalendarManager()
        let appState = isolatedAppState(name: "appStateReactsToEvents", calendar: mock)
        appState.calendarIntegrationEnabled = true

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: now)

        let schedule = Schedule(
            name: "Work",
            days: [today],
            startTime: now.addingTimeInterval(-1800),
            endTime: now.addingTimeInterval(1800),
            isEnabled: true
        )
        appState.schedules = [schedule]
        #expect(appState.isBlocking == true)

        let meeting = ExternalEvent(
            id: "m1",
            title: "Meeting",
            startDate: now.addingTimeInterval(-300),
            endDate: now.addingTimeInterval(300)
        )

        mock.events = [meeting]
        appState.checkSchedules()
        #expect(appState.isBlocking == false, "Should unblock because of calendar meeting")
    }

    @Test("RealCalendarManager deinit invalidates refresh timer")
    func realCalendarManagerDeinitInvalidatesTimer() {
        let scheduler = MockRepeatingTimerScheduler()
        let runtimeState = CalendarRuntimeState()
        var manager: RealCalendarManager? = RealCalendarManager(
            timerScheduler: scheduler,
            runtime: runtimeState.makeRuntime(),
            nowProvider: Date.init
        )
        #expect(manager != nil)

        #expect(scheduler.intervals == [300.0])
        #expect(scheduler.timers.count == 1)
        let timer = scheduler.timers[0]

        manager = nil
        let deadline = Date().addingTimeInterval(0.2)
        while timer.invalidateCallCount == 0 && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        #expect(timer.invalidateCallCount == 1)
    }
}
