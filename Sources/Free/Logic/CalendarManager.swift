import Foundation
import Combine
import EventKit

protocol CalendarProvider: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    var events: [ExternalEvent] { get set }
    var isAuthorized: Bool { get }
    func requestAccess()
    func fetchEvents()
}

class RealCalendarManager: CalendarProvider {
    @Published var events: [ExternalEvent] = []
    @Published var isAuthorized: Bool = false

    private let runtime: CalendarManagerRuntime
    private let timerScheduler: any RepeatingTimerScheduling
    private let nowProvider: () -> Date
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

        refreshTimer = timerScheduler.scheduledRepeatingTimer(withTimeInterval: 5 * 60) { [weak self] in
            self?.fetchEvents()
        }
    }

    deinit {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func requestAccess() {
        let runtime = self.runtime
        runtime.requestEventAccess { [weak self] granted in
            guard let self else { return }
            runtime.dispatchMain {
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
        let startRange = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now))!
        let endRange = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))!

        let snapshots = runtime.loadEvents(startRange, endRange)

        let mapped = snapshots.compactMap { snapshot -> ExternalEvent? in
            if snapshot.isAllDay { return nil }
            return ExternalEvent(
                id: "\(snapshot.eventIdentifier ?? UUID().uuidString)-\(snapshot.startDate.timeIntervalSince1970)",
                title: snapshot.title ?? "Untitled Event",
                startDate: snapshot.startDate,
                endDate: snapshot.endDate
            )
        }

        runtime.dispatchMain { [weak self] in
            self?.events = mapped
        }
    }
}

// Dummy for when we don't want any calendar logic (e.g. basic tests)
class MockCalendarManager: CalendarProvider {
    @Published var events: [ExternalEvent] = []
    @Published var isAuthorized: Bool = true
    func requestAccess() {}
    func fetchEvents() {}
}
