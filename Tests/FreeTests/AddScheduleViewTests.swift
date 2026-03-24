import Testing
import AppKit
import Foundation
@testable import FreeLogic

@Suite(.serialized)
struct AddScheduleViewTests {
    private final class TestDeleteAlert: NSAlert {
        override func runModal() -> NSApplication.ModalResponse {
            .alertSecondButtonReturn
        }
    }

    private func isolatedAppState(name: String) -> AppState {
        let suite = "AddScheduleViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host(
        _ controller: NSViewController,
        size: CGSize = CGSize(width: 520, height: 700)
    ) -> NSView {
        let hosted = controller.view
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

    private func actionButtons(in view: NSView) -> [ActionButton] {
        var all: [ActionButton] = []
        if let button = view as? ActionButton {
            all.append(button)
        }
        for child in view.subviews {
            all.append(contentsOf: actionButtons(in: child))
        }
        return all
    }

    private func popups(in view: NSView) -> [NSPopUpButton] {
        var all: [NSPopUpButton] = []
        if let popup = view as? NSPopUpButton {
            all.append(popup)
        }
        for child in view.subviews {
            all.append(contentsOf: popups(in: child))
        }
        return all
    }

    private func visibleText(in view: NSView) -> [String] {
        guard !view.isHidden, view.alphaValue > 0.001 else { return [] }

        var values: [String] = []
        if let label = view as? NSTextField, !label.stringValue.isEmpty {
            values.append(label.stringValue)
        }
        if let button = view as? NSButton, !button.title.isEmpty {
            values.append(button.title)
        }

        for child in view.subviews {
            values.append(contentsOf: visibleText(in: child))
        }
        return values
    }

    private func makeController(
        appState: AppState,
        context: ScheduleEditorContext = ScheduleEditorContext(),
        onClose: @escaping () -> Void = {}
    ) -> ScheduleEditorViewController {
        ScheduleEditorViewController(
            appState: appState,
            context: context,
            onRequestClose: onClose
        )
    }

    @Test("Schedule editor support covers focus/break and scheduling branches")
    func addScheduleViewHelperLogic() {
        let existing = Schedule(name: "Existing", days: [2, 3], startTime: Date(), endTime: Date().addingTimeInterval(3600), colorIndex: 1, type: .focus)

        #expect(ScheduleEditorSupport.shouldShowAllowedList(for: .focus))
        #expect(!ScheduleEditorSupport.shouldShowAllowedList(for: .unfocus))
        #expect(!ScheduleEditorSupport.isImportedSchedule(existing))
        #expect(ScheduleEditorSupport.canDeleteSchedule(existingSchedule: existing))
        #expect(ScheduleEditorSupport.canEditImportedScheduleDetails(existingSchedule: existing))

        #expect(ScheduleEditorSupport.shouldShowEditScope(existingSchedule: existing, initialDay: 2))
        #expect(!ScheduleEditorSupport.shouldShowEditScope(existingSchedule: existing, initialDay: nil))
        #expect(!ScheduleEditorSupport.shouldShowEditScope(existingSchedule: nil, initialDay: 2))
        #expect(!ScheduleEditorSupport.shouldShowEditScope(existingSchedule: Schedule(name: "single", days: [2], startTime: Date(), endTime: Date()), initialDay: 2))

        #expect(ScheduleEditorSupport.scheduleNamePlaceholder(for: .focus) == "Focus Session")
        #expect(ScheduleEditorSupport.scheduleNamePlaceholder(for: .unfocus) == "Break Session")

        #expect(ScheduleEditorSupport.shouldShowSingleDayBadge(existingSchedule: existing, modifyAllDays: false, initialDay: 2))
        #expect(!ScheduleEditorSupport.shouldShowSingleDayBadge(existingSchedule: existing, modifyAllDays: true, initialDay: 2))
        #expect(!ScheduleEditorSupport.shouldShowSingleDayBadge(existingSchedule: nil, modifyAllDays: false, initialDay: 2))

        #expect(ScheduleEditorSupport.weekDayOrder(weekStartsOnMonday: true) == [2, 3, 4, 5, 6, 7, 1])
        #expect(ScheduleEditorSupport.weekDayOrder(weekStartsOnMonday: false) == [1, 2, 3, 4, 5, 6, 7])

        #expect(ScheduleEditorSupport.toggledDays([2, 3], day: 2) == [3])
        #expect(ScheduleEditorSupport.toggledDays([2, 3], day: 4) == [2, 3, 4])

        #expect(ScheduleEditorSupport.saveButtonTitle(existingSchedule: nil, sessionType: .focus) == "Add Focus Session")
        #expect(ScheduleEditorSupport.saveButtonTitle(existingSchedule: nil, sessionType: .unfocus) == "Add Break Session")
        #expect(ScheduleEditorSupport.saveButtonTitle(existingSchedule: existing, sessionType: .focus) == "Save Changes")

        #expect(ScheduleEditorSupport.primaryButtonColor(sessionType: .unfocus, accentColorIndex: 0) == .systemOrange)
        #expect(ScheduleEditorSupport.primaryButtonColor(sessionType: .focus, accentColorIndex: 3) == FocusColor.nsColor(for: 3))
        #expect(ScheduleEditorSupport.daySymbol(at: 2) == "M")

        #expect(ScheduleEditorSupport.isSaveDisabled(days: [], modifyAllDays: true, isRecurring: true))
        #expect(!ScheduleEditorSupport.isSaveDisabled(days: [2], modifyAllDays: true, isRecurring: true))
        #expect(!ScheduleEditorSupport.isSaveDisabled(days: [], modifyAllDays: false, isRecurring: true))
        #expect(!ScheduleEditorSupport.isSaveDisabled(days: [], modifyAllDays: true, isRecurring: false))

        #expect(ScheduleEditorSupport.shouldApplyNewScheduleDefaults(existingSchedule: nil))
        #expect(!ScheduleEditorSupport.shouldApplyNewScheduleDefaults(existingSchedule: existing))

        var imported = existing
        imported.importedCalendarEventKey = "imported-event"
        #expect(ScheduleEditorSupport.isImportedSchedule(imported))
        #expect(!ScheduleEditorSupport.canDeleteSchedule(existingSchedule: imported))
        #expect(!ScheduleEditorSupport.canEditImportedScheduleDetails(existingSchedule: imported))
        #expect(ScheduleEditorSupport.canEditImportedScheduleDetails(existingSchedule: nil))
        #expect(!ScheduleEditorSupport.canDeleteSchedule(existingSchedule: nil))

        #expect(ScheduleEditorSupport.dayName(for: 1) == Calendar.current.weekdaySymbols[0])

        #expect(
            ScheduleEditorSupport.shouldConfirmDeleteForMultiDayRecurring(
                existingSchedule: existing,
                modifyAllDays: true
            )
        )
        #expect(
            !ScheduleEditorSupport.shouldConfirmDeleteForMultiDayRecurring(
                existingSchedule: existing,
                modifyAllDays: false
            )
        )
        #expect(
            !ScheduleEditorSupport.shouldConfirmDeleteForMultiDayRecurring(
                existingSchedule: Schedule(
                    name: "One-Off",
                    days: [2, 3],
                    date: Date(),
                    startTime: Date(),
                    endTime: Date().addingTimeInterval(600)
                ),
                modifyAllDays: true
            )
        )
        #expect(
            !ScheduleEditorSupport.shouldConfirmDeleteForMultiDayRecurring(
                existingSchedule: Schedule(
                    name: "Single Day",
                    days: [2],
                    startTime: Date(),
                    endTime: Date().addingTimeInterval(600)
                ),
                modifyAllDays: true
            )
        )
        #expect(
            !ScheduleEditorSupport.shouldConfirmDeleteForMultiDayRecurring(
                existingSchedule: nil,
                modifyAllDays: true
            )
        )
    }

    @Test("Schedule editor support save payload maps recurring and one-off correctly")
    func addScheduleViewSavePayload() {
        let recurring = ScheduleEditorSupport.savePayload(days: [2, 3], isRecurring: true, initialDay: 2, weekOffset: 0, weekStartsOnMonday: false)
        #expect(recurring.days == [2, 3])
        #expect(recurring.date == nil)

        let oneOff = ScheduleEditorSupport.savePayload(days: [2], isRecurring: false, initialDay: 2, weekOffset: 0, weekStartsOnMonday: false)
        #expect(oneOff.date != nil)
        if let targetDate = oneOff.date {
            #expect(oneOff.days == [Calendar.current.component(.weekday, from: targetDate)])
        }

        let fallback = ScheduleEditorSupport.savePayload(days: [2], isRecurring: false, initialDay: nil, weekOffset: 0, weekStartsOnMonday: false)
        let expectedFallbackDate = Schedule.calculateOneOffDate(initialDay: nil, weekOffset: 0, weekStartsOnMonday: false)
        #expect(fallback.date == expectedFallbackDate)
        if let expectedFallbackDate {
            #expect(fallback.days == [Calendar.current.component(.weekday, from: expectedFallbackDate)])
        }

        let invalidDay = ScheduleEditorSupport.savePayload(days: [2], isRecurring: false, initialDay: 0, weekOffset: 0, weekStartsOnMonday: false)
        #expect(invalidDay.days == [2])
        #expect(invalidDay.date == nil)
    }

    @Test("ScheduleEditorViewController renders new schedule form")
    @MainActor
    func addScheduleViewRender() {
        let appState = isolatedAppState(name: "renderAndSave")
        appState.accentColorIndex = 4
        appState.ruleSets = [RuleSet(name: "Allowlist", urls: ["example.com"])]

        let controller = makeController(appState: appState)
        let hosted = host(controller)
        #expect(hosted.fittingSize.width >= 0)
        #expect(controller.headerTitleForTesting == "New Schedule")
        #expect(controller.sessionTypeSelectionColorForTesting == FocusColor.nsColor(for: 4))
    }

    @Test("ScheduleEditorViewController header renders close button and dismisses")
    @MainActor
    func addScheduleViewCloseButtonRenders() {
        let appState = isolatedAppState(name: "closeButton")
        var closeCount = 0
        let controller = makeController(appState: appState) {
            closeCount += 1
        }
        let hosted = host(controller)

        let closeButton = buttons(in: hosted).first { $0.title.isEmpty }
        #expect(closeButton != nil)
        controller.dismissForTesting()
        #expect(closeCount == 1)
    }

    @Test("ScheduleEditorViewController renders edit scope path")
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

        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(
                day: 2,
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                schedule: schedule
            )
        )
        let hosted = host(controller)
        #expect(hosted.fittingSize.height >= 0)
        #expect(controller.headerTitleForTesting == "Edit Schedule")
    }

    @Test("ScheduleEditorViewController can render single-day recurring badge path")
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

        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(
                day: 3,
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                schedule: schedule
            )
        )
        let hosted = host(controller)
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("ScheduleEditorViewController can render break-session path without allowed list")
    @MainActor
    func addScheduleViewBreakPath() {
        let appState = isolatedAppState(name: "breakPath")
        appState.accentColorIndex = 6
        let schedule = Schedule(
            name: "Break Session",
            days: [2],
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            colorIndex: 3,
            type: .unfocus
        )

        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                schedule: schedule
            )
        )
        let hosted = host(controller)
        let texts = visibleText(in: hosted)
        #expect(hosted.fittingSize.height >= 0)
        #expect(controller.sessionTypeSelectionColorForTesting == FocusColor.nsColor(for: 6))
        #expect(texts.contains("ALLOWED LIST"))
        #expect(texts.contains("Not used for breaks"))
    }

    @Test("ScheduleEditorViewController does not reload the whole form when toggling repeat weekly")
    @MainActor
    func addScheduleViewRepeatToggleStaysInPlace() {
        let appState = isolatedAppState(name: "repeatToggle")
        let controller = makeController(appState: appState)
        _ = host(controller)

        let initialReloadGeneration = controller.formReloadGenerationForTesting

        #expect(controller.isRecurringDaysSectionHiddenForTesting == false)
        #expect(controller.areRecurringDayButtonsEnabledForTesting == false)

        controller.setRecurringForTesting(true)

        #expect(controller.formReloadGenerationForTesting == initialReloadGeneration)
        #expect(controller.isRecurringDaysSectionHiddenForTesting == false)
        #expect(controller.areRecurringDayButtonsEnabledForTesting == true)

        controller.setRecurringForTesting(false)

        #expect(controller.formReloadGenerationForTesting == initialReloadGeneration)
        #expect(controller.isRecurringDaysSectionHiddenForTesting == false)
        #expect(controller.areRecurringDayButtonsEnabledForTesting == false)
    }

    @Test("ScheduleEditorViewController keeps save disabled in strict mode during recurring UI updates")
    @MainActor
    func addScheduleViewStrictModeDisablesSaveThroughRecurringRefresh() {
        let appState = isolatedAppState(name: "strictModeDisablesSaveThroughRecurringRefresh")
        appState.isStrict = true
        appState.isBlocking = true

        let controller = makeController(appState: appState)
        let hosted = host(controller)

        let initialSave = actionButtons(in: hosted).first(where: { $0.title.contains("Add") })
        #expect(initialSave?.isEnabled == false)

        controller.setRecurringForTesting(true)
        let updatedSave = actionButtons(in: hosted).first(where: { $0.title.contains("Add") })
        #expect(updatedSave?.isEnabled == false)
    }

    @Test("ScheduleEditorViewController renders imported schedule editor with limited editable sections")
    @MainActor
    func addScheduleViewImportedPath() {
        let appState = isolatedAppState(name: "importedPath")
        appState.ruleSets = [RuleSet(name: "Allowlist", urls: ["example.com"])]

        var imported = Schedule(
            name: "Imported Focus",
            days: [2],
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            colorIndex: 1,
            type: .focus
        )
        imported.importedCalendarEventKey = "calendar-event"

        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(
                startTime: imported.startTime,
                endTime: imported.endTime,
                schedule: imported
            )
        )
        let hosted = host(controller)
        #expect(hosted.fittingSize.width >= 0)
        #expect(controller.importedScheduleForTesting)
        #expect(!controller.canEditImportedDetailsForTesting)
    }

    @Test("ScheduleEditorViewController save schedule persists and dismisses")
    func addScheduleViewPerformSave() {
        let appState = isolatedAppState(name: "performSave")
        appState.ruleSets = [RuleSet(name: "Allowlist", urls: ["example.com"])]

        var closeCount = 0
        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(day: 2),
            onClose: { closeCount += 1 }
        )
        let before = appState.schedules.count
        controller.saveScheduleForTesting()
        #expect(appState.schedules.count == before + 1)
        #expect(closeCount == 1)
    }

    @Test("ScheduleEditorViewController delete schedule removes and dismisses")
    func addScheduleViewPerformDelete() {
        defer { ScheduleEditorViewController.resetDeleteConfirmationHooksForTesting() }
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

        var closeCount = 0
        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(
                day: 2,
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                schedule: schedule
            ),
            onClose: { closeCount += 1 }
        )
        controller.deleteScheduleForTesting()
        #expect(!appState.schedules.contains(where: { $0.id == schedule.id }))
        #expect(closeCount == 1)
    }

    @Test("ScheduleEditorViewController delete confirms multi-day recurring schedule before deleting")
    @MainActor
    func addScheduleViewDeleteRequiresConfirmationForRecurringMultiDay() {
        defer { ScheduleEditorViewController.resetDeleteConfirmationHooksForTesting() }
        let appState = isolatedAppState(name: "deleteRecurringConfirm")
        let schedule = Schedule(
            name: "Recurring Focus",
            days: [2, 3, 4],
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            colorIndex: 0,
            type: .focus
        )
        appState.schedules = [schedule]

        var closeCount = 0
        var alertShown = 0
        ScheduleEditorViewController.makeDeleteConfirmationAlert = { NSAlert() }
        ScheduleEditorViewController.runDeleteConfirmationAlert = { _ in
            alertShown += 1
            return .alertSecondButtonReturn
        }

        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(
                day: 2,
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                schedule: schedule
            ),
            onClose: { closeCount += 1 }
        )

        controller.deleteScheduleForTesting()
        #expect(alertShown == 1)
        #expect(appState.schedules.contains(where: { $0.id == schedule.id }))
        #expect(closeCount == 0)

        ScheduleEditorViewController.runDeleteConfirmationAlert = { _ in
            alertShown += 1
            return .alertFirstButtonReturn
        }
        controller.deleteScheduleForTesting()
        #expect(alertShown == 2)
        #expect(!appState.schedules.contains(where: { $0.id == schedule.id }))
        #expect(closeCount == 1)
    }

    @Test("ScheduleEditorViewController delete uses XCTest fast path when confirmation hooks are not overridden")
    func addScheduleViewDeleteUsesXCTestFastPathWithoutAlertHooks() {
        defer { ScheduleEditorViewController.resetDeleteConfirmationHooksForTesting() }
        let appState = isolatedAppState(name: "deleteUsesXCTestFastPathWithoutAlertHooks")
        let schedule = Schedule(
            name: "Recurring Focus",
            days: [2, 3, 4],
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            colorIndex: 0,
            type: .focus
        )
        appState.schedules = [schedule]

        var closeCount = 0
        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(
                day: 2,
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                schedule: schedule
            ),
            onClose: { closeCount += 1 }
        )

        ScheduleEditorViewController.resetDeleteConfirmationHooksForTesting()
        controller.deleteScheduleForTesting()
        #expect(appState.schedules.contains(where: { $0.id == schedule.id }) == false)
        #expect(closeCount == 1)
    }

    @Test("ScheduleEditorViewController delete confirmation hooks expose default and override paths")
    @MainActor
    func addScheduleViewDeleteConfirmationHookCoverage() {
        defer { ScheduleEditorViewController.resetDeleteConfirmationHooksForTesting() }
        ScheduleEditorViewController.resetDeleteConfirmationHooksForTesting()

        let defaultFactory = ScheduleEditorViewController.makeDeleteConfirmationAlert
        let defaultRunner = ScheduleEditorViewController.runDeleteConfirmationAlert
        #expect(type(of: defaultFactory()) == NSAlert.self)
        #expect(defaultRunner(NSAlert()) == .alertFirstButtonReturn)

        ScheduleEditorViewController.setRunningInTestProcessHookForTesting { false }
        #expect(defaultRunner(TestDeleteAlert()) == .alertSecondButtonReturn)

        var customFactoryCalled = false
        var customRunnerCalled = false
        ScheduleEditorViewController.makeDeleteConfirmationAlert = {
            customFactoryCalled = true
            return NSAlert()
        }
        ScheduleEditorViewController.runDeleteConfirmationAlert = { _ in
            customRunnerCalled = true
            return .alertFirstButtonReturn
        }
        _ = ScheduleEditorViewController.makeDeleteConfirmationAlert()
        _ = ScheduleEditorViewController.runDeleteConfirmationAlert(NSAlert())
        #expect(customFactoryCalled)
        #expect(customRunnerCalled)
    }

    @Test("ScheduleEditorViewController control handlers update editor state")
    @MainActor
    func addScheduleViewControlHandlers() {
        let appState = isolatedAppState(name: "controlHandlers")
        let firstSet = RuleSet(name: "One", urls: [])
        let secondSet = RuleSet(name: "Two", urls: [])
        appState.ruleSets = [firstSet, secondSet]

        let controller = makeController(appState: appState)
        _ = host(controller)

        controller.setNameForTesting("Edited Name")
        #expect(controller.nameForTesting == "Edited Name")

        controller.selectRuleSetIndexForTesting(2)
        #expect(controller.ruleSetIdForTesting == secondSet.id)

        let newStart = Date().addingTimeInterval(1200)
        let newEnd = newStart.addingTimeInterval(1800)
        controller.changeStartTimeForTesting(newStart)
        controller.changeEndTimeForTesting(newEnd)
        #expect(controller.startTimeForTesting == newStart)
        #expect(controller.endTimeForTesting == newEnd)

        let originalDays = controller.daysForTesting
        controller.toggleRecurringForTesting(true)
        controller.toggleRecurringDayForTesting(2)
        #expect(controller.daysForTesting != originalDays)

        controller.toggleRecurringForTesting(false)
        let daysBeforeNoopToggle = controller.daysForTesting
        controller.toggleRecurringDayForTesting(3)
        #expect(controller.daysForTesting == daysBeforeNoopToggle)

        // Guard branch: non-NSTextField object should no-op.
        controller.controlTextDidChangeForTesting(object: NSView())
        #expect(controller.nameForTesting == "Edited Name")

        // Guard branch: delete with no existing schedule should no-op.
        let beforeDelete = appState.schedules.count
        controller.deleteScheduleForTesting()
        #expect(appState.schedules.count == beforeDelete)
    }

    @Test("Schedule editor UI interactions trigger selection closures and button actions")
    @MainActor
    func addScheduleViewInteractiveClosureCoverage() {
        defer { ScheduleEditorViewController.resetDeleteConfirmationHooksForTesting() }
        let appState = isolatedAppState(name: "interactiveClosureCoverage")
        appState.ruleSets = [
            RuleSet(name: "One", urls: ["one.com"]),
            RuleSet(name: "Two", urls: ["two.com"]),
        ]
        let schedule = Schedule(
            name: "Recurring Focus",
            days: [2, 3, 4],
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            colorIndex: 0,
            type: .focus
        )
        appState.schedules = [schedule]

        var closeCount = 0
        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(
                day: 2,
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                schedule: schedule
            ),
            onClose: { closeCount += 1 }
        )
        let hosted = host(controller)
        let initialGeneration = controller.formReloadGenerationForTesting

        let breakButton = buttons(in: hosted).first { $0.title == "Break" }
        #expect(breakButton != nil)
        breakButton?.performClick(nil)
        #expect(controller.formReloadGenerationForTesting > initialGeneration)
        #expect(visibleText(in: hosted).contains("Not used for breaks"))

        let onlyDayTitle = "Only \(ScheduleEditorSupport.dayName(for: 2))"
        let onlyDayButton = buttons(in: hosted).first { $0.title == onlyDayTitle }
        #expect(onlyDayButton != nil)
        onlyDayButton?.performClick(nil)
        #expect(visibleText(in: hosted).contains(ScheduleEditorSupport.dayName(for: 2)))

        let colorButton = actionButtons(in: hosted).first(where: { button in
            button.title.isEmpty && abs((button.layer?.cornerRadius ?? 0) - 15) < 0.1
        })
        #expect(colorButton != nil)
        colorButton?.performClick(nil)
        #expect(controller.formReloadGenerationForTesting > initialGeneration)

        let saveButton = buttons(in: hosted).first { $0.title == "Save Changes" }
        #expect(saveButton != nil)
        let beforeSaveCount = appState.schedules.count
        saveButton?.performClick(nil)
        #expect(appState.schedules.count >= beforeSaveCount)
        #expect(closeCount == 1)

        let deleteState = isolatedAppState(name: "interactiveClosureCoverageDelete")
        deleteState.ruleSets = appState.ruleSets
        deleteState.schedules = [schedule]
        closeCount = 0
        let deletingController = makeController(
            appState: deleteState,
            context: ScheduleEditorContext(
                day: 2,
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                schedule: schedule
            ),
            onClose: { closeCount += 1 }
        )
        let deletingView = host(deletingController)
        let deleteButton = buttons(in: deletingView).first { $0.title == "Delete Schedule" }
        #expect(deleteButton != nil)
        deleteButton?.performClick(nil)
        #expect(deleteState.schedules.isEmpty)
        #expect(closeCount == 1)
    }

    @Test("Schedule editor allowed-list popup falls back to None when current rule-set is missing")
    @MainActor
    func addScheduleViewAllowedListPopupFallbackCoverage() {
        let appState = isolatedAppState(name: "allowedListFallback")
        appState.ruleSets = [RuleSet(name: "Known", urls: ["known.com"])]

        let schedule = Schedule(
            name: "Focus with missing list",
            days: [2],
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            type: .focus,
            ruleSetId: UUID()
        )

        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(
                day: 2,
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                schedule: schedule
            )
        )
        let hosted = host(controller)
        #expect(hosted.fittingSize.width >= 0)
        let allowedListPopup = popups(in: hosted).first { popup in
            popup.itemArray.contains(where: { $0.title == "None" }) &&
                popup.itemArray.contains(where: { $0.title == "Known" })
        }
        #expect(allowedListPopup != nil)
        #expect(allowedListPopup?.selectedItem?.title == "None")
    }

    @Test("Schedule editor recurring day button actions trigger toggle closures")
    @MainActor
    func addScheduleViewRecurringDayButtonClosureCoverage() {
        let appState = isolatedAppState(name: "recurringDayButtonClosures")
        let controller = makeController(appState: appState)
        let hosted = host(controller)
        controller.setRecurringForTesting(true)

        let daySymbols = Set(["S", "M", "T", "W", "F"])
        let beforeDays = controller.daysForTesting
        let dayButton = buttons(in: hosted).first { daySymbols.contains($0.title) }
        #expect(dayButton != nil)
        dayButton?.performClick(nil)
        #expect(controller.daysForTesting != beforeDays)
    }

    @Test("Schedule editor save/delete are blocked while strict mode is active")
    @MainActor
    func addScheduleViewStrictModeBlocksSaveAndDelete() {
        let appState = isolatedAppState(name: "strictModeBlocksSaveAndDelete")
        var schedule = Schedule(
            name: "Strict Existing",
            days: [2],
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            colorIndex: 2,
            type: .focus
        )
        appState.schedules = [schedule]
        appState.isStrict = true
        appState.isBlocking = true

        var closeCount = 0
        let controller = makeController(
            appState: appState,
            context: ScheduleEditorContext(
                day: 2,
                startTime: schedule.startTime,
                endTime: schedule.endTime,
                schedule: schedule
            ),
            onClose: { closeCount += 1 }
        )
        _ = host(controller)

        let beforeSaveCount = appState.schedules.count
        controller.saveScheduleForTesting()
        #expect(appState.schedules.count == beforeSaveCount)
        #expect(closeCount == 0)

        schedule = appState.schedules[0]
        controller.deleteScheduleForTesting()
        #expect(appState.schedules.contains(where: { $0.id == schedule.id }))
        #expect(closeCount == 0)
    }
}
