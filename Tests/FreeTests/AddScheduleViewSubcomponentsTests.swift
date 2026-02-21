import Testing
import SwiftUI
import AppKit
import Foundation
@testable import FreeLogic

@Suite(.serialized)
struct AddScheduleViewSubcomponentsTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "AddScheduleViewSubcomponentsTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 520, height: 220)) -> NSHostingView<V> {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    @Test("AddScheduleThemeColorRow updates bound selectedColorIndex via generated action")
    @MainActor
    func addScheduleThemeColorRowTapAction() {
        var selectedColorIndex = 0
        let binding = Binding(get: { selectedColorIndex }, set: { selectedColorIndex = $0 })
        let row = AddScheduleThemeColorRow(selectedColorIndex: binding)
        let hosted = host(row, size: CGSize(width: 700, height: 80))
        #expect(hosted.fittingSize.width >= 0)

        let selectColor = AddScheduleThemeColorRow.makeSelectColorAction(selectedColorIndex: binding, index: 1)
        selectColor()
        #expect(selectedColorIndex == 1)
    }

    @Test("AddScheduleRecurringDaysRow toggles day selection via generated action")
    @MainActor
    func addScheduleRecurringDaysRowDayToggleAction() {
        let appState = isolatedAppState(name: "toggleAction")
        appState.weekStartsOnMonday = false

        var days: Set<Int> = [2]
        let binding = Binding(get: { days }, set: { days = $0 })
        let row = AddScheduleRecurringDaysRow(
            existingSchedule: nil,
            modifyAllDays: true,
            initialDay: nil,
            days: binding
        )
        .environmentObject(appState)

        let hosted = host(row, size: CGSize(width: 700, height: 120))
        #expect(hosted.fittingSize.width >= 0)

        let toggleDay = AddScheduleRecurringDaysRow.makeToggleDayAction(days: binding, day: 4)
        toggleDay()
        #expect(days == [2, 4])

        let toggleExistingDay = AddScheduleRecurringDaysRow.makeToggleDayAction(days: binding, day: 2)
        toggleExistingDay()
        #expect(days == [4])
    }

    @Test("AddScheduleRecurringDaysRow renders single-day badge branch")
    @MainActor
    func addScheduleRecurringDaysRowBadgeBranch() {
        let appState = isolatedAppState(name: "badgeBranch")
        let schedule = Schedule(name: "Recurring", days: [2, 3], startTime: Date(), endTime: Date().addingTimeInterval(3600))

        var days: Set<Int> = [2, 3]
        let binding = Binding(get: { days }, set: { days = $0 })
        let row = AddScheduleRecurringDaysRow(
            existingSchedule: schedule,
            modifyAllDays: false,
            initialDay: 2,
            days: binding
        )
        .environmentObject(appState)

        let hosted = host(row, size: CGSize(width: 320, height: 120))
        #expect(hosted.fittingSize.width >= 0)
    }
}
