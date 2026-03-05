import Testing
import AppKit
import Foundation
@testable import FreeLogic

@Suite(.serialized)
struct SchedulesViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "SchedulesViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host(
        _ controller: NSViewController,
        size: CGSize = CGSize(width: 900, height: 760)
    ) -> NSView {
        let hosted = controller.view
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    private func allSubviews(in view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { allSubviews(in: $0) }
    }

    private func sampleSchedule(name: String) -> Schedule {
        Schedule(
            name: name,
            days: [2, 3],
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            colorIndex: 1,
            type: .focus
        )
    }

    @Test("Schedules sheet controller actions cover delete, remove-at-offsets, select, and open add")
    @MainActor
    func schedulesViewActionLogic() {
        let appState = isolatedAppState(name: "actions")
        let first = sampleSchedule(name: "First")
        let second = sampleSchedule(name: "Second")
        appState.schedules = [first, second]

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 0
        )
        let hosted = host(controller)
        #expect(hosted.fittingSize.width >= 0)

        controller.deleteScheduleForTesting(scheduleId: first.id)
        #expect(appState.schedules.contains(where: { $0.id == first.id }) == false)

        let countBeforeMissingDelete = appState.schedules.count
        controller.deleteScheduleForTesting(scheduleId: UUID())
        #expect(appState.schedules.count == countBeforeMissingDelete)

        appState.schedules = [second, sampleSchedule(name: "Third")]
        controller.removeSchedulesForTesting(at: IndexSet(integer: 0))
        #expect(appState.schedules.count == 1)

        controller.selectScheduleForTesting(second)
        #expect(controller.editorContextForTesting?.schedule?.id == second.id)

        controller.openAddScheduleForTesting()
        #expect(controller.editorContextForTesting != nil)
    }

    @Test("Schedules sheet controller does not delete imported schedules from row or swipe actions")
    @MainActor
    func schedulesViewPreventsImportedDeletion() {
        let appState = isolatedAppState(name: "preventsImportedDeletion")
        appState.calendarIntegrationEnabled = true
        appState.calendarImportsBlockTime = true

        let now = Date()
        let importedEvent = ExternalEvent(
            id: "calendar-import",
            title: "Imported",
            startDate: now.addingTimeInterval(-300),
            endDate: now.addingTimeInterval(300)
        )
        appState.calendarProvider.events = [importedEvent]
        let local = sampleSchedule(name: "Local")
        appState.schedules = [local]
        appState.checkSchedules()

        guard let imported = appState.schedules.first(where: { $0.importedCalendarEventKey == "calendar-import" }) else {
            Issue.record("Expected imported schedule to be mirrored before delete checks")
            return
        }

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 0
        )

        controller.deleteScheduleForTesting(scheduleId: imported.id)
        #expect(appState.schedules.contains(where: { $0.id == imported.id }))

        controller.removeSchedulesForTesting(at: IndexSet(integer: 0))
        #expect(appState.schedules.contains(where: { $0.id == imported.id }))

        controller.removeSchedulesForTesting(at: IndexSet(integer: 1))
        #expect(!appState.schedules.contains(where: { $0.id == local.id }))
        #expect(appState.schedules.contains(where: { $0.id == imported.id }))
    }

    @Test("Schedules sheet controller renders list mode with schedules")
    @MainActor
    func schedulesViewListModeRender() {
        let appState = isolatedAppState(name: "listMode")
        appState.schedules = [sampleSchedule(name: "A"), sampleSchedule(name: "B")]

        let hosted = host(
            SchedulesSheetViewController(
                appState: appState,
                onDismiss: {},
                initialViewMode: 0
            )
        )
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("Schedules sheet controller renders calendar mode")
    @MainActor
    func schedulesViewCalendarModeRender() {
        let appState = isolatedAppState(name: "calendarMode")
        appState.schedules = [sampleSchedule(name: "A")]

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 1
        )
        let hosted = host(controller)
        #expect(hosted.fittingSize.height >= 0)
        #expect(controller.viewModeForTesting == 1)
    }

    @Test("Schedules sheet controller skips full refresh for unrelated app-state changes")
    @MainActor
    func schedulesViewSkipsRefreshForUnrelatedStateChanges() {
        let appState = isolatedAppState(name: "unrelatedRefresh")
        appState.schedules = [sampleSchedule(name: "A")]

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 1
        )
        _ = host(controller)
        let initialRefreshGeneration = controller.refreshGenerationForTesting

        appState.currentOpenUrls = ["https://example.com"]
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        #expect(controller.refreshGenerationForTesting == initialRefreshGeneration)
    }

    @Test("Schedules sheet controller exposes visible AppKit toolbar controls in calendar mode")
    @MainActor
    func schedulesViewCalendarModeShowsToolbarControls() {
        let appState = isolatedAppState(name: "calendarToolbar")
        appState.schedules = [sampleSchedule(name: "A")]

        let hosted = host(
            SchedulesSheetViewController(
                appState: appState,
                onDismiss: {},
                initialViewMode: 1
            ),
            size: CGSize(width: 900, height: 760)
        )
        let subviews = allSubviews(in: hosted)

        let segmentedControls = subviews.compactMap { $0 as? NSSegmentedControl }
        #expect(segmentedControls.contains(where: { !$0.isHidden && $0.segmentCount == 2 }))

        let buttons = subviews.compactMap { $0 as? NSButton }
        #expect(buttons.contains(where: { !$0.isHidden && $0.title == "Today" }))
        #expect(buttons.contains(where: { !$0.isHidden && $0.title == "Done" }) == false)
    }

    @Test("Schedules sheet controller supports a preset editor context")
    @MainActor
    func schedulesViewPresetEditorSheetRender() {
        let appState = isolatedAppState(name: "doneBinding")
        let schedule = sampleSchedule(name: "Edit")
        appState.schedules = [schedule]
        let context = ScheduleEditorContext(
            day: 2,
            startTime: schedule.startTime,
            endTime: schedule.endTime,
            schedule: schedule,
            weekOffset: 0
        )

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 1,
            initialEditorContext: context
        )
        let hosted = host(controller, size: CGSize(width: 900, height: 800))
        #expect(hosted.fittingSize.width >= 0)
        #expect(controller.editorContextForTesting?.schedule?.id == schedule.id)
    }
}
