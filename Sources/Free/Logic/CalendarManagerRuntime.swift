import Foundation
import EventKit

struct CalendarEventSnapshot {
    let eventIdentifier: String?
    let title: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}

struct CalendarManagerRuntime {
    var hasEventAuthorization: () -> Bool
    var requestEventAccess: (@escaping (Bool) -> Void) -> Void
    var loadEvents: (_ start: Date, _ end: Date) -> [CalendarEventSnapshot]
    var dispatchMain: (@escaping () -> Void) -> Void
}

extension CalendarManagerRuntime {
    static func live(eventStore: EKEventStore = EKEventStore()) -> CalendarManagerRuntime {
        CalendarManagerRuntime(
            hasEventAuthorization: {
                let status = EKEventStore.authorizationStatus(for: .event)
                return status == .fullAccess || status.rawValue == 3
            },
            requestEventAccess: { completion in
                if #available(macOS 14.0, *) {
                    eventStore.requestFullAccessToEvents { granted, _ in
                        completion(granted)
                    }
                } else {
                    eventStore.requestAccess(to: .event) { granted, _ in
                        completion(granted)
                    }
                }
            },
            loadEvents: { startRange, endRange in
                let predicate = eventStore.predicateForEvents(
                    withStart: startRange,
                    end: endRange,
                    calendars: eventStore.calendars(for: .event)
                )
                let ekEvents = eventStore.events(matching: predicate)
                return ekEvents.map { event in
                    CalendarEventSnapshot(
                        eventIdentifier: event.eventIdentifier,
                        title: event.title,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        isAllDay: event.isAllDay
                    )
                }
            },
            dispatchMain: { work in
                DispatchQueue.main.async(execute: work)
            }
        )
    }
}
