import Foundation
import EventKit
import Combine

protocol CalendarProvider: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    var events: [ExternalEvent] { get set }
    var isAuthorized: Bool { get }
    func requestAccess()
    func fetchEvents()
}

class RealCalendarManager: CalendarProvider {
    @Published var events: [ExternalEvent] = []
    @Published var isAuthorized: Bool = false
    
    private let eventStore = EKEventStore()
    private let timerScheduler: any RepeatingTimerScheduling
    private var refreshTimer: (any RepeatingTimer)?
    
    init(timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler()) {
        self.timerScheduler = timerScheduler
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || (status.rawValue == 3) {
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
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.fetchEvents() }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.fetchEvents() }
                }
            }
        }
    }
    
    func fetchEvents() {
        guard isAuthorized else { return }
        let calendar = Calendar.current
        let now = Date()
        let startRange = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now))!
        let endRange = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))!
        
        let predicate = eventStore.predicateForEvents(withStart: startRange, end: endRange, calendars: eventStore.calendars(for: .event))
        let ekEvents = eventStore.events(matching: predicate)
        
        let mapped = ekEvents.compactMap { ekEvent -> ExternalEvent? in
            if ekEvent.isAllDay { return nil }
            return ExternalEvent(
                id: "\(ekEvent.eventIdentifier ?? UUID().uuidString)-\(ekEvent.startDate.timeIntervalSince1970)",
                title: ekEvent.title ?? "Untitled Event",
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate
            )
        }
        
        DispatchQueue.main.async { [weak self] in
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
