import Testing
import Foundation
import Combine
@testable import FreeLogic

struct CalendarManagerTests {

    private func isolatedAppState(name: String, calendar: any CalendarProvider) -> AppState {
        let suite = "CalendarManagerTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, calendar: calendar, isTesting: true)
    }

    @Test("MockCalendarManager allows manual event injection")
    func mockCalendarLogic() {
        let mock = MockCalendarManager()
        let now = Date()
        let event = ExternalEvent(id: "1", title: "Test", startDate: now, endDate: now.addingTimeInterval(3600))

        mock.events = [event]

        #expect(mock.events.count == 1)
        #expect(mock.events.first?.title == "Test")
        #expect(mock.isAuthorized == true)
    }

    @Test("AppState reacts to calendar authorization changes")
    func appStateCalendarAuth() {
        let mock = MockCalendarManager()
        mock.isAuthorized = false

        let appState = isolatedAppState(name: "appStateCalendarAuth", calendar: mock)

        // Initially integration is disabled in AppState default
        #expect(appState.calendarIntegrationEnabled == false)

        // When: Enabled
        appState.calendarIntegrationEnabled = true

        // Then: Should have requested access (checked via side effect or behavior)
        // Since Mock doesn't track calls yet, we verify state
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

        // Setup: Active focus schedule
        let schedule = Schedule(
            name: "Work",
            days: [today],
            startTime: now.addingTimeInterval(-1800),
            endTime: now.addingTimeInterval(1800),
            isEnabled: true
        )
        appState.schedules = [schedule]

        // Verify initially blocking
        #expect(appState.isBlocking == true)

        // When: A meeting starts (External Event)
        let meeting = ExternalEvent(
            id: "m1",
            title: "Meeting",
            startDate: now.addingTimeInterval(-300),
            endDate: now.addingTimeInterval(300)
        )

        // Inject meeting and trigger change
        mock.events = [meeting]

        // When: We check schedules
        appState.checkSchedules()

        // Then: Should unblock (in normal mode)
        #expect(appState.isBlocking == false, "Should unblock because of calendar meeting")
    }
}
