import Testing
import Foundation
import EventKit
@testable import FreeLogic

// Thread-safe holder so a value captured in a @Sendable completion can be read
// back after the callback fires.
private final class Holder<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: T
    init(_ value: T) { storedValue = value }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return storedValue }
        set { lock.lock(); defer { lock.unlock() }; storedValue = newValue }
    }
}

private final class RuntimeEventStoreDouble: EKEventStore {
    var requestFullAccessCalls = 0
    var requestAccessCalls = 0
    var requestFullAccessResult = true
    var requestAccessResult = true
    var lastRequestEntityType: EKEntityType?

    var calendarsCalls = 0
    var predicateCalls = 0
    var eventsMatchingCalls = 0

    var capturedStart: Date?
    var capturedEnd: Date?
    var capturedCalendars: [EKCalendar] = []
    var capturedPredicate: NSPredicate?

    var stubCalendars: [EKCalendar] = []
    var stubPredicate = NSPredicate(value: true)
    var stubEvents: [EKEvent] = []

    override func requestFullAccessToEvents(completion: @escaping EKEventStoreRequestAccessCompletionHandler) {
        requestFullAccessCalls += 1
        completion(requestFullAccessResult, nil)
    }

    override func requestAccess(to entityType: EKEntityType, completion: @escaping EKEventStoreRequestAccessCompletionHandler) {
        requestAccessCalls += 1
        lastRequestEntityType = entityType
        completion(requestAccessResult, nil)
    }

    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        calendarsCalls += 1
        return stubCalendars
    }

    override func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate {
        predicateCalls += 1
        capturedStart = startDate
        capturedEnd = endDate
        capturedCalendars = calendars ?? []
        return stubPredicate
    }

    override func events(matching predicate: NSPredicate) -> [EKEvent] {
        eventsMatchingCalls += 1
        capturedPredicate = predicate
        return stubEvents
    }
}

@Suite(.serialized)
@MainActor
struct CalendarManagerRuntimeTests {
    @Test("live runtime default initializer path can be constructed")
    func liveDefaultInitializerPath() async throws {
        let runtime = CalendarManagerRuntime.live(eventStore: EKEventStore())
        let status = EKEventStore.authorizationStatus(for: .event)
        let expected = status == .fullAccess || status.rawValue == 3

        #expect(runtime.hasEventAuthorization() == expected)
    }

    @Test("live runtime forwards authorization status through hasEventAuthorization")
    func liveAuthorizationStatus() async throws {
        let store = RuntimeEventStoreDouble()
        let runtime = CalendarManagerRuntime.live(eventStore: store)
        let status = EKEventStore.authorizationStatus(for: .event)
        let expected = status == .fullAccess || status.rawValue == 3

        #expect(runtime.hasEventAuthorization() == expected)
    }

    @Test("live runtime requestEventAccess uses full-access API on modern macOS")
    func liveRequestAccessUsesModernApi() async throws {
        let store = RuntimeEventStoreDouble()
        store.requestFullAccessResult = true
        store.requestAccessResult = false

        let runtime = CalendarManagerRuntime.live(eventStore: store)
        let grantedValue = Holder<Bool?>(nil)
        runtime.requestEventAccess { granted in
            grantedValue.value = granted
        }

        #expect(store.requestFullAccessCalls == 1)
        #expect(store.requestAccessCalls == 0)
        #expect(grantedValue.value == true)
    }

    @Test("live runtime loadEvents maps EventKit events into snapshots")
    func liveLoadEventsMapping() async throws {
        let store = RuntimeEventStoreDouble()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(7200)
        let calendar = EKCalendar(for: .event, eventStore: store)
        store.stubCalendars = [calendar]
        store.stubPredicate = NSPredicate(format: "TRUEPREDICATE")

        let first = EKEvent(eventStore: store)
        first.title = "Meeting"
        first.startDate = start
        first.endDate = start.addingTimeInterval(1800)
        first.isAllDay = false

        let second = EKEvent(eventStore: store)
        second.title = "All Day"
        second.startDate = start.addingTimeInterval(3600)
        second.endDate = end
        second.isAllDay = true

        store.stubEvents = [first, second]

        let runtime = CalendarManagerRuntime.live(eventStore: store)
        let snapshots = runtime.loadEvents(start, end)

        #expect(store.calendarsCalls == 1)
        #expect(store.predicateCalls == 1)
        #expect(store.eventsMatchingCalls == 1)
        #expect(store.capturedStart == start)
        #expect(store.capturedEnd == end)
        #expect(store.capturedCalendars.count == 1)
        #expect(store.capturedPredicate == store.stubPredicate)

        #expect(snapshots.count == 2)
        #expect(snapshots[0].title == "Meeting")
        #expect(snapshots[0].startDate == start)
        #expect(snapshots[0].endDate == start.addingTimeInterval(1800))
        #expect(snapshots[0].isAllDay == false)
        #expect(snapshots[1].title == "All Day")
        #expect(snapshots[1].isAllDay == true)
    }

}
