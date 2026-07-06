import Observation
import EventKit
import Foundation

@MainActor
protocol CalendarProvider: AnyObject {
    var events: [ExternalEvent] { get set }
    var isAuthorized: Bool { get }
    func requestAccess()
    func fetchEvents()
}

@MainActor
@Observable
class RealCalendarManager: CalendarProvider {
    var events: [ExternalEvent] = []
    var isAuthorized: Bool = false

    private let runtime: CalendarManagerRuntime
    private let timerScheduler: any RepeatingTimerScheduling
    private let nowProvider: () -> Date
    @ObservationIgnored
    private var refreshTimer: (any RepeatingTimer)?

    init(
        timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler(),
        runtime: CalendarManagerRuntime = .live(eventStore: EKEventStore()),
        nowProvider: @escaping () -> Date
    ) {
        self.runtime = runtime
        self.timerScheduler = timerScheduler
        self.nowProvider = nowProvider

        if runtime.hasEventAuthorization() {
            self.isAuthorized = true
            self.fetchEvents()
        }

        refreshTimer = timerScheduler.scheduledRepeatingTimer(withTimeInterval: 5 * 60) {
            [weak self] in
            Task { @MainActor [weak self] in
                self?.fetchEvents()
            }
        }
    }

    isolated deinit {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func requestAccess() {
        let runtime = self.runtime
        runtime.requestEventAccess { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAuthorized = granted
                if granted {
                    self.fetchEvents()
                }
            }
        }
    }

    func fetchEvents() {
        guard isAuthorized else { return }
        let calendar = Calendar.current
        let now = nowProvider()
        guard
            let startRange = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)),
            let endRange = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))
        else { return }

        let snapshots = runtime.loadEvents(startRange, endRange)

        let mapped = snapshots.compactMap { snapshot -> ExternalEvent? in
            if snapshot.isAllDay { return nil }
            return ExternalEvent(
                id:
                    "\(snapshot.eventIdentifier ?? UUID().uuidString)-\(snapshot.startDate.timeIntervalSince1970)",
                title: snapshot.title ?? "Untitled Event",
                startDate: snapshot.startDate,
                endDate: snapshot.endDate
            )
        }

        self.events = mapped
    }
}

@MainActor
@Observable
class MockCalendarManager: CalendarProvider {
    var events: [ExternalEvent] = []
    var isAuthorized: Bool = true
    var requestAccessCallCount = 0
    func requestAccess() {
        requestAccessCallCount += 1
    }
    func fetchEvents() {}
}
