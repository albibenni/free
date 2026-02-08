import Foundation
import EventKit
import Combine

class CalendarManager: ObservableObject {
    @Published var events: [ExternalEvent] = []
    @Published var isAuthorized: Bool = false
    
    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?
    
    init() {
        requestAccess()
        
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
        
        // Fetch events for a 2-week window (-7 to +7 days) to ensure we cover the current view
        let startRange = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now))!
        let endRange = calendar.date(byAdding: .day, value: 7, to: startRange)!
        
        // Fetch all calendars
        let calendars = eventStore.calendars(for: .event)
        
        let predicate = eventStore.predicateForEvents(withStart: startRange, end: endRange, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)
        
        // Map to our model
        let mappedEvents = ekEvents.compactMap { ekEvent -> ExternalEvent? in
            // Filter out all-day events as requested
            if ekEvent.isAllDay { return nil }
            
            return ExternalEvent(
                id: ekEvent.eventIdentifier,
                title: ekEvent.title,
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate
            )
        }
        
        DispatchQueue.main.async {
            self.events = mappedEvents
        }
    }
}
