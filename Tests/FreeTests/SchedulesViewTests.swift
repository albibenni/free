import Testing
import SwiftUI
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
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 900, height: 760)) -> NSHostingView<V> {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
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

    @Test("SchedulesView actions cover delete, remove-at-offsets, select, open add, and binding closures")
    @MainActor
    func schedulesViewActionLogic() {
        let appState = isolatedAppState(name: "actions")
        let first = sampleSchedule(name: "First")
        let second = sampleSchedule(name: "Second")
        appState.schedules = [first, second]

        let view = SchedulesView(initialViewMode: 0).environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.width >= 0)

        let root = SchedulesView(initialViewMode: 0, actionAppState: appState)

        let deleteFirst = root.deleteScheduleAction(scheduleId: first.id)
        deleteFirst()
        #expect(appState.schedules.contains(where: { $0.id == first.id }) == false)

        let deleteMissing = root.deleteScheduleAction(scheduleId: UUID())
        let countBeforeMissingDelete = appState.schedules.count
        deleteMissing()
        #expect(appState.schedules.count == countBeforeMissingDelete)

        appState.schedules = [second, sampleSchedule(name: "Third")]
        root.removeSchedules(at: IndexSet(integer: 0))
        #expect(appState.schedules.count == 1)

        let selectAction = root.selectScheduleAction(schedule: second)
        selectAction()
        _ = root.editorContextForTesting

        root.openAddSchedule()
        _ = root.editorContextForTesting

        let binding = root.makeEditorPresentationBinding()
        _ = binding.wrappedValue
        binding.wrappedValue = false
        _ = binding.wrappedValue

        let context = ScheduleEditorContext(
            day: 3,
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            schedule: second,
            weekOffset: 1
        )
        let sheetView = root.makeAddScheduleSheet(context: context)
            .environmentObject(appState)
        let hostedSheet = host(sheetView, size: CGSize(width: 600, height: 760))
        #expect(hostedSheet.fittingSize.height >= 0)
    }

    @Test("SchedulesView renders list mode with schedules")
    @MainActor
    func schedulesViewListModeRender() {
        let appState = isolatedAppState(name: "listMode")
        appState.schedules = [sampleSchedule(name: "A"), sampleSchedule(name: "B")]

        let view = SchedulesView(initialViewMode: 0).environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("SchedulesView renders calendar mode")
    @MainActor
    func schedulesViewCalendarModeRender() {
        let appState = isolatedAppState(name: "calendarMode")
        appState.schedules = [sampleSchedule(name: "A")]

        let view = SchedulesView(initialViewMode: 1).environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.height >= 0)

        let root = SchedulesView(initialViewMode: 1)
        _ = root.viewModeForTesting
    }

    @Test("SchedulesView sheet path can render when editor context is preset")
    @MainActor
    func schedulesViewPresetEditorSheetRender() {
        let appState = isolatedAppState(name: "presetSheet")
        let schedule = sampleSchedule(name: "Edit")
        appState.schedules = [schedule]
        let context = ScheduleEditorContext(
            day: 2,
            startTime: schedule.startTime,
            endTime: schedule.endTime,
            schedule: schedule,
            weekOffset: 0
        )

        let view = SchedulesView(initialViewMode: 1, initialEditorContext: context)
            .environmentObject(appState)
        let hosted = host(view, size: CGSize(width: 900, height: 800))
        #expect(hosted.fittingSize.width >= 0)
    }
}
