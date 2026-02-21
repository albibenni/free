import Testing
import SwiftUI
import AppKit
import Foundation
@testable import FreeLogic

@Suite(.serialized)
struct AddScheduleViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "AddScheduleViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 520, height: 700)) -> NSHostingView<V> {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    private func buttons(in view: NSView) -> [NSButton] {
        var all: [NSButton] = []
        if let button = view as? NSButton {
            all.append(button)
        }
        for child in view.subviews {
            all.append(contentsOf: buttons(in: child))
        }
        return all
    }

    @Test("AddScheduleView helper logic covers focus/break and scheduling branches")
    func addScheduleViewHelperLogic() {
        let existing = Schedule(name: "Existing", days: [2, 3], startTime: Date(), endTime: Date().addingTimeInterval(3600), colorIndex: 1, type: .focus)

        #expect(AddScheduleView.shouldShowAllowedList(for: .focus))
        #expect(!AddScheduleView.shouldShowAllowedList(for: .unfocus))

        #expect(AddScheduleView.shouldShowEditScope(existingSchedule: existing, initialDay: 2))
        #expect(!AddScheduleView.shouldShowEditScope(existingSchedule: existing, initialDay: nil))
        #expect(!AddScheduleView.shouldShowEditScope(existingSchedule: nil, initialDay: 2))
        #expect(!AddScheduleView.shouldShowEditScope(existingSchedule: Schedule(name: "single", days: [2], startTime: Date(), endTime: Date()), initialDay: 2))

        #expect(AddScheduleView.scheduleNamePlaceholder(for: .focus) == "Focus Session")
        #expect(AddScheduleView.scheduleNamePlaceholder(for: .unfocus) == "Break Session")

        #expect(AddScheduleView.shouldShowSingleDayBadge(existingSchedule: existing, modifyAllDays: false, initialDay: 2))
        #expect(!AddScheduleView.shouldShowSingleDayBadge(existingSchedule: existing, modifyAllDays: true, initialDay: 2))
        #expect(!AddScheduleView.shouldShowSingleDayBadge(existingSchedule: nil, modifyAllDays: false, initialDay: 2))

        #expect(AddScheduleView.weekDayOrder(weekStartsOnMonday: true) == [2, 3, 4, 5, 6, 7, 1])
        #expect(AddScheduleView.weekDayOrder(weekStartsOnMonday: false) == [1, 2, 3, 4, 5, 6, 7])

        #expect(AddScheduleView.toggledDays([2, 3], day: 2) == [3])
        #expect(AddScheduleView.toggledDays([2, 3], day: 4) == [2, 3, 4])

        #expect(AddScheduleView.saveButtonTitle(existingSchedule: nil, sessionType: .focus) == "Add Focus Session")
        #expect(AddScheduleView.saveButtonTitle(existingSchedule: nil, sessionType: .unfocus) == "Add Break Session")
        #expect(AddScheduleView.saveButtonTitle(existingSchedule: existing, sessionType: .focus) == "Save Changes")

        #expect(AddScheduleView.primaryButtonColor(sessionType: .unfocus, accentColorIndex: 0) == .orange)
        #expect(AddScheduleView.primaryButtonColor(sessionType: .focus, accentColorIndex: 3) == FocusColor.color(for: 3))

        #expect(AddScheduleView.isSaveDisabled(days: [], modifyAllDays: true))
        #expect(!AddScheduleView.isSaveDisabled(days: [2], modifyAllDays: true))
        #expect(!AddScheduleView.isSaveDisabled(days: [], modifyAllDays: false))

        #expect(AddScheduleView.shouldApplyNewScheduleDefaults(existingSchedule: nil))
        #expect(!AddScheduleView.shouldApplyNewScheduleDefaults(existingSchedule: existing))

        #expect(AddScheduleView.dayName(for: 1) == Calendar.current.weekdaySymbols[0])
    }

    @Test("AddScheduleView save payload maps recurring and one-off correctly")
    func addScheduleViewSavePayload() {
        let recurring = AddScheduleView.savePayload(days: [2, 3], isRecurring: true, initialDay: 2, weekOffset: 0, weekStartsOnMonday: false)
        #expect(recurring.days == [2, 3])
        #expect(recurring.date == nil)

        let oneOff = AddScheduleView.savePayload(days: [2], isRecurring: false, initialDay: 2, weekOffset: 0, weekStartsOnMonday: false)
        #expect(oneOff.date != nil)
        if let targetDate = oneOff.date {
            #expect(oneOff.days == [Calendar.current.component(.weekday, from: targetDate)])
        }

        let fallback = AddScheduleView.savePayload(days: [2], isRecurring: false, initialDay: nil, weekOffset: 0, weekStartsOnMonday: false)
        let expectedFallbackDate = Schedule.calculateOneOffDate(initialDay: nil, weekOffset: 0, weekStartsOnMonday: false)
        #expect(fallback.date == expectedFallbackDate)
        if let expectedFallbackDate {
            #expect(fallback.days == [Calendar.current.component(.weekday, from: expectedFallbackDate)])
        }

        let invalidDay = AddScheduleView.savePayload(days: [2], isRecurring: false, initialDay: 0, weekOffset: 0, weekStartsOnMonday: false)
        #expect(invalidDay.days == [2])
        #expect(invalidDay.date == nil)
    }

    @Test("AddScheduleView renders new schedule form")
    @MainActor
    func addScheduleViewRender() {
        let appState = isolatedAppState(name: "renderAndSave")
        appState.ruleSets = [RuleSet(name: "Allowlist", urls: ["example.com"])]

        var presented = true
        let binding = Binding(get: { presented }, set: { presented = $0 })
        let view = AddScheduleView(isPresented: binding)
            .environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.width >= 0)
        #expect(presented == true)
    }

    @Test("AddScheduleView header renders close button")
    @MainActor
    func addScheduleViewCloseButtonRenders() {
        let appState = isolatedAppState(name: "closeButton")
        var presented = true
        let binding = Binding(get: { presented }, set: { presented = $0 })
        let view = AddScheduleView(isPresented: binding)
            .environmentObject(appState)
        let hosted = host(view)

        let closeButton = buttons(in: hosted).first { $0.title.isEmpty }
        #expect(closeButton != nil)
        #expect(presented == true)

        let actionView = AddScheduleView(isPresented: binding, actionAppState: appState)
        actionView.dismissAction()
        #expect(presented == false)
    }

    @Test("AddScheduleView renders edit scope path")
    @MainActor
    func addScheduleViewRenderEdit() {
        let appState = isolatedAppState(name: "renderEditAndDelete")
        let schedule = Schedule(
            name: "Recurring Focus",
            days: [2, 3, 4],
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            colorIndex: 2,
            type: .focus
        )
        appState.schedules = [schedule]

        var presented = true
        let binding = Binding(get: { presented }, set: { presented = $0 })
        let view = AddScheduleView(
            isPresented: binding,
            initialDay: 2,
            existingSchedule: schedule,
            initialIsRecurring: true
        )
        .environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.height >= 0)
        #expect(presented == true)
    }

    @Test("AddScheduleView can render single-day recurring badge path")
    @MainActor
    func addScheduleViewSingleDayBadgePath() {
        let appState = isolatedAppState(name: "singleDayBadgePath")
        let schedule = Schedule(
            name: "Recurring Focus",
            days: [2, 3, 4],
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            colorIndex: 0,
            type: .focus
        )

        var presented = true
        let binding = Binding(get: { presented }, set: { presented = $0 })
        let view = AddScheduleView(
            isPresented: binding,
            initialDay: 3,
            existingSchedule: schedule,
            initialModifyAllDays: false,
            initialIsRecurring: true
        )
        .environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("AddScheduleView can render break-session path without allowed list")
    @MainActor
    func addScheduleViewBreakPath() {
        let appState = isolatedAppState(name: "breakPath")
        let schedule = Schedule(
            name: "Break Session",
            days: [2],
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            colorIndex: 3,
            type: .unfocus
        )

        var presented = true
        let binding = Binding(get: { presented }, set: { presented = $0 })
        let view = AddScheduleView(
            isPresented: binding,
            existingSchedule: schedule,
            initialIsRecurring: false,
            initialSessionType: .unfocus
        )
        .environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.height >= 0)
    }

    @Test("DayToggle helper logic and render path are covered")
    @MainActor
    func dayToggleLogicAndRender() {
        let appState = isolatedAppState(name: "dayToggle")
        appState.accentColorIndex = 2

        #expect(DayToggle.daySymbol(at: 2) == "M")
        #expect(DayToggle.backgroundColor(isSelected: true, accentColorIndex: 2) == FocusColor.color(for: 2))
        #expect(DayToggle.foregroundColor(isSelected: true) == .white)
        #expect(DayToggle.foregroundColor(isSelected: false) == .primary)

        var count = 0
        let selected = DayToggle(day: 2, isSelected: true) { count += 1 }.environmentObject(appState)
        let hostedSelected = host(selected, size: CGSize(width: 80, height: 80))
        #expect(hostedSelected.fittingSize.width >= 0)

        let unselected = DayToggle(day: 3, isSelected: false) { count += 1 }.environmentObject(appState)
        let hostedUnselected = host(unselected, size: CGSize(width: 80, height: 80))
        #expect(hostedUnselected.fittingSize.height >= 0)
        #expect(count == 0)

    }

    @Test("AddScheduleView performSave and performSaveAction save schedule and dismiss")
    func addScheduleViewPerformSave() {
        let appState = isolatedAppState(name: "performSave")
        appState.ruleSets = [RuleSet(name: "Allowlist", urls: ["example.com"])]

        var presented = true
        let binding = Binding(get: { presented }, set: { presented = $0 })
        let view = AddScheduleView(isPresented: binding, initialDay: 2, initialIsRecurring: true)

        let before = appState.schedules.count
        view.performSave(using: appState)
        #expect(appState.schedules.count == before + 1)
        #expect(presented == false)

        presented = true
        let actionView = AddScheduleView(isPresented: binding, initialDay: 2, initialIsRecurring: true, actionAppState: appState)
        let beforeAction = appState.schedules.count
        actionView.performSaveAction()
        #expect(appState.schedules.count == beforeAction + 1)
        #expect(presented == false)
    }

    @Test("AddScheduleView performDelete and performDeleteAction remove schedule and dismiss")
    func addScheduleViewPerformDelete() {
        let appState = isolatedAppState(name: "performDelete")
        let schedule = Schedule(
            name: "Recurring Focus",
            days: [2, 3, 4],
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            colorIndex: 0,
            type: .focus
        )
        appState.schedules = [schedule]

        var presented = true
        let binding = Binding(get: { presented }, set: { presented = $0 })
        let view = AddScheduleView(isPresented: binding, initialDay: 2, existingSchedule: schedule, initialModifyAllDays: true, initialIsRecurring: true)

        view.performDelete(using: appState)
        #expect(!appState.schedules.contains(where: { $0.id == schedule.id }))
        #expect(presented == false)

        appState.schedules = [schedule]
        presented = true
        let actionView = AddScheduleView(isPresented: binding, initialDay: 2, existingSchedule: schedule, initialModifyAllDays: true, initialIsRecurring: true, actionAppState: appState)
        actionView.performDeleteAction()
        #expect(!appState.schedules.contains(where: { $0.id == schedule.id }))
        #expect(presented == false)
    }
}
