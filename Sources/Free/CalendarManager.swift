import Foundation
import EventKit
import Combine

class CalendarManager: ObservableObject {
    @Published var events: [ExternalEvent] = []
    @Published var isAuthorized: Bool = false
    
    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?
    
    init() {
        // Only fetch if already authorized, don't trigger prompt yet
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || (status.rawValue == 3 /* authorized fallback */) {
            self.isAuthorized = true
            self.fetchEvents()
        }
        
        // Refresh every 5 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            self?.fetchEvents()
        }
    }
    
    func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.fetchEvents()
                    } else {
                        print("Calendar access denied: \(String(describing: error))")
                    }
                }
            }
        } else {
            // Fallback for older macOS
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.fetchEvents()
                    }
                }
            }
        }
    }
    
    func fetchEvents() {
        guard isAuthorized else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // Fetch events for a 2-week window: 7 days before and 7 days after today
        let startRange = calendar.date(byAdding: .day, value: -7, to: startOfDay)!
        let endRange = calendar.date(byAdding: .day, value: 7, to: startOfDay)!
        
        // Fetch all calendars
        let calendars = eventStore.calendars(for: .event)
        
        let predicate = eventStore.predicateForEvents(withStart: startRange, end: endRange, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)
        
        // Map to our model
        let mappedEvents = ekEvents.compactMap { ekEvent -> ExternalEvent? in
            if ekEvent.isAllDay { return nil }
            
            // For recurring events, ekEvent.eventIdentifier might be the same for all occurrences.
            // We create a unique ID by combining identifier and start date.
            let uniqueId = "\(ekEvent.eventIdentifier ?? UUID().uuidString)-\(ekEvent.startDate.timeIntervalSince1970)"
            
            return ExternalEvent(
                id: uniqueId,
                title: ekEvent.title ?? "Untitled Event",
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate
            )
        }
        
        DispatchQueue.main.async {
            self.events = mappedEvents
        }
    }
}
