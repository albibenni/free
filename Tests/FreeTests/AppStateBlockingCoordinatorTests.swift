import Foundation
import Testing

@testable import FreeLogic

struct AppStateBlockingCoordinatorTests {
    @Test("evaluateAutomaticBlocking normalizes paused ids and keeps blocking false without active focus")
    func evaluateAutomaticBlockingNoFocus() {
        let result = AppStateBlockingCoordinator.evaluateAutomaticBlocking(
            schedules: [],
            manuallyPausedScheduleIds: [UUID()],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: true,
            isStrict: false,
            calendarEvents: []
        )

        #expect(result.shouldBlock == false)
        #expect(result.normalizedManuallyPausedScheduleIds.isEmpty)
    }

    @Test("evaluateAutomaticBlocking blocks when pomodoro focus is active and no break overrides")
    func evaluateAutomaticBlockingPomodoroFocus() {
        let result = AppStateBlockingCoordinator.evaluateAutomaticBlocking(
            schedules: [],
            manuallyPausedScheduleIds: [],
            pomodoroStatus: .focus,
            calendarIntegrationEnabled: false,
            isStrict: false,
            calendarEvents: []
        )

        #expect(result.shouldBlock)
        #expect(result.normalizedManuallyPausedScheduleIds.isEmpty)
    }

    @Test("evaluateAutomaticBlocking does not treat mirrored imported focus event as meeting override")
    func evaluateAutomaticBlockingMirroredImportedFocus() {
        let now = Date()
        let importedFocus = Schedule(
            name: "Work",
            days: [],
            date: now,
            startTime: now.addingTimeInterval(-600),
            endTime: now.addingTimeInterval(600),
            isEnabled: true,
            type: .focus,
            importedCalendarEventKey: "event-focus"
        )
        let event = ExternalEvent(
            id: "event-focus",
            title: "Work",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600)
        )

        let result = AppStateBlockingCoordinator.evaluateAutomaticBlocking(
            schedules: [importedFocus],
            manuallyPausedScheduleIds: [],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: true,
            isStrict: false,
            calendarEvents: [event]
        )

        #expect(result.shouldBlock)
    }

    @Test("evaluateAutomaticBlocking still treats unrelated active event as meeting override")
    func evaluateAutomaticBlockingUnrelatedMeetingOverride() {
        let now = Date()
        let importedFocus = Schedule(
            name: "Work",
            days: [],
            date: now,
            startTime: now.addingTimeInterval(-600),
            endTime: now.addingTimeInterval(600),
            isEnabled: true,
            type: .focus,
            importedCalendarEventKey: "event-focus"
        )
        let focusEvent = ExternalEvent(
            id: "event-focus",
            title: "Work",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600)
        )
        let meetingEvent = ExternalEvent(
            id: "event-meeting",
            title: "Video Call",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600)
        )

        let result = AppStateBlockingCoordinator.evaluateAutomaticBlocking(
            schedules: [importedFocus],
            manuallyPausedScheduleIds: [],
            pomodoroStatus: .none,
            calendarIntegrationEnabled: true,
            isStrict: false,
            calendarEvents: [focusEvent, meetingEvent]
        )

        #expect(result.shouldBlock == false)
    }
}
