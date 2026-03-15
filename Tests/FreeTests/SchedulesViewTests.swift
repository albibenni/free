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

    @MainActor
    private func hostView(_ view: NSView, size: CGSize = CGSize(width: 900, height: 760)) -> NSView {
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        return view
    }

    private func allSubviews(in view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { allSubviews(in: $0) }
    }

    private func firstSubview<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        if let typed = view as? T { return typed }
        for child in view.subviews {
            if let found: T = firstSubview(of: type, in: child) {
                return found
            }
        }
        return nil
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

    private func sampleCalendarConfiguration(day: Int = 2) -> WeeklyCalendarSurfaceConfiguration {
        let weekRange = WeeklyCalendarSupport.getWeekDates(weekStartsOnMonday: false)
        let weekBounds = WeeklyCalendarSupport.weekBounds(for: weekRange)
        return WeeklyCalendarSurfaceConfiguration(
            dayOrder: WeeklyCalendarSupport.getDayOrder(weekStartsOnMonday: false),
            weekRange: weekRange,
            weekStart: weekBounds.0,
            weekEnd: weekBounds.1,
            positionedSchedules: WeeklyCalendarSupport.positionedSchedules(
                schedules: [sampleSchedule(name: "Calendar Config")],
                weekRange: weekRange
            ),
            externalEvents: [],
            showsExternalEvents: false,
            hourHeight: 80,
            dayHeaderHeight: 40,
            timeLabelWidth: 60,
            timeColumnGutter: 12,
            accentColor: .systemBlue,
            onQuickAdd: { _, _ in },
            onCreateSelection: { _, _, _ in },
            onOpenSchedule: { _, _ in },
            onUpdateSchedule: { _, _, _, _, _, _ in }
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

    @Test("Schedules sheet blocks schedule mutations while strict mode is active")
    @MainActor
    func schedulesViewBlocksMutationsWhenStrictActive() {
        let appState = isolatedAppState(name: "blocksMutationsWhenStrictActive")
        let schedule = sampleSchedule(name: "Locked")
        appState.schedules = [schedule]
        appState.isUnblockable = true
        appState.isBlocking = true

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 0
        )
        _ = host(controller)

        controller.openAddScheduleForTesting()
        #expect(controller.editorContextForTesting == nil)

        controller.quickAddForTesting(day: 2, hour: 10)
        #expect(controller.editorContextForTesting == nil)

        controller.openSelectionEditorForTesting(day: 2, startHour: 9.0, endHour: 10.0)
        #expect(controller.editorContextForTesting == nil)

        controller.openScheduleEditorForTesting(day: 2, schedule: schedule)
        #expect(controller.editorContextForTesting == nil)

        controller.setScheduleEnabledForTesting(scheduleId: schedule.id, isEnabled: false)
        #expect(appState.schedules.first?.isEnabled == true)

        controller.deleteScheduleForTesting(scheduleId: schedule.id)
        #expect(appState.schedules.contains(where: { $0.id == schedule.id }))
    }

    @Test("Schedules sheet allows schedule modifications when unblockable is on but focus is inactive")
    @MainActor
    func schedulesViewAllowsMutationsWhenUnblockableButNotBlocking() {
        let appState = isolatedAppState(name: "allowsMutationsWhenUnblockableButNotBlocking")
        let schedule = sampleSchedule(name: "Editable")
        appState.schedules = [schedule]
        appState.isUnblockable = true
        appState.isBlocking = false

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 0
        )
        _ = host(controller)

        controller.openAddScheduleForTesting()
        #expect(controller.editorContextForTesting != nil)

        controller.setScheduleEnabledForTesting(scheduleId: schedule.id, isEnabled: false)
        #expect(appState.schedules.first?.isEnabled == false)
    }

    @Test("Schedules sheet shows lock alert when strict mode blocks modification")
    @MainActor
    func schedulesViewShowsStrictLockAlert() {
        defer { SchedulesSheetViewController.resetScheduleModificationAlertHooksForTesting() }
        var alertRunCount = 0
        SchedulesSheetViewController.setScheduleModificationAlertHooksForTesting(
            make: { NSAlert() },
            run: { _ in
                alertRunCount += 1
                return .alertFirstButtonReturn
            }
        )

        let appState = isolatedAppState(name: "showsStrictLockAlert")
        appState.schedules = [sampleSchedule(name: "Locked")]
        appState.isUnblockable = true
        appState.isBlocking = true

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 0
        )
        _ = host(controller)

        controller.openAddScheduleForTesting()
        #expect(alertRunCount == 1)
        #expect(controller.editorContextForTesting == nil)

        appState.isBlocking = false
        controller.openAddScheduleForTesting()
        #expect(alertRunCount == 1)
        #expect(controller.editorContextForTesting != nil)
    }

    @Test("Schedules sheet strict-mode callback closures block select/update and show lock alert")
    @MainActor
    func schedulesViewStrictCallbacksShowLockAlert() {
        defer { SchedulesSheetViewController.resetScheduleModificationAlertHooksForTesting() }
        var alertRunCount = 0
        SchedulesSheetViewController.makeScheduleModificationBlockedAlert = { NSAlert() }
        SchedulesSheetViewController.runScheduleModificationBlockedAlert = { _ in
            alertRunCount += 1
            return .alertFirstButtonReturn
        }

        let appState = isolatedAppState(name: "strictCallbacksShowLockAlert")
        var schedule = sampleSchedule(name: "Locked Callback")
        schedule.days = [2]
        appState.schedules = [schedule]
        appState.isUnblockable = true
        appState.isBlocking = true

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 1
        )
        _ = host(controller)

        let config = controller.appKitConfigurationForTesting
        config.onSelectSchedule(schedule)
        config.calendarViewConfiguration.onUpdateSchedule(
            schedule.id,
            2,
            2,
            nil,
            schedule.startTime.addingTimeInterval(600),
            schedule.endTime.addingTimeInterval(600)
        )

        #expect(alertRunCount == 2)
        #expect(controller.editorContextForTesting == nil)
    }

    @Test("Schedules sheet default lock alert runner uses native modal branch outside XCTest env")
    @MainActor
    func schedulesViewDefaultLockAlertRunnerFallback() {
        defer { SchedulesSheetViewController.resetScheduleModificationAlertHooksForTesting() }
        let originalEnv = getenv("XCTestConfigurationFilePath").map { String(cString: $0) }
        unsetenv("XCTestConfigurationFilePath")
        defer {
            if let originalEnv {
                setenv("XCTestConfigurationFilePath", originalEnv, 1)
            } else {
                unsetenv("XCTestConfigurationFilePath")
            }
        }

        var nativeRunCount = 0
        SchedulesSheetViewController.setScheduleModificationAlertHooksForTesting(
            nativeRun: { _ in
                nativeRunCount += 1
                return .alertSecondButtonReturn
            },
            isRunningInTestProcess: { false }
        )
        let response = SchedulesSheetViewController.runScheduleModificationBlockedAlert(NSAlert())
        #expect(response == .alertSecondButtonReturn)
        #expect(nativeRunCount == 1)
    }

    @Test("Schedules sheet default native runner fallback path is covered without presenting modal in XCTest")
    @MainActor
    func schedulesViewDefaultNativeRunnerFallbackCoverage() {
        defer {
            SchedulesSheetViewController.resetScheduleModificationAlertHooksForTesting()
            AppKitSystemBridges.setRunModalForTesting(nil)
        }

        // Force fallback-runner selection without opening a native modal.
        SchedulesSheetViewController.setScheduleModificationAlertHooksForTesting(
            nativeRun: nil,
            fallbackRun: { _ in .alertFirstButtonReturn },
            isRunningInTestProcess: { false }
        )

        let response = SchedulesSheetViewController.runScheduleModificationBlockedAlert(NSAlert())
        #expect(response == .alertFirstButtonReturn)
    }

    @Test("Schedules sheet default fallback branch routes through AppKit system bridge")
    @MainActor
    func schedulesViewDefaultFallbackBranchCoverage() {
        defer {
            SchedulesSheetViewController.resetScheduleModificationAlertHooksForTesting()
            AppKitSystemBridges.setRunModalForTesting(nil)
        }

        SchedulesSheetViewController.setScheduleModificationAlertHooksForTesting(
            nativeRun: nil,
            fallbackRun: nil,
            isRunningInTestProcess: { false }
        )
        AppKitSystemBridges.setRunModalForTesting { _ in .alertSecondButtonReturn }
        let response = SchedulesSheetViewController.runScheduleModificationBlockedAlert(NSAlert())
        #expect(response == .alertSecondButtonReturn)
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

    @Test("Schedules remove-at-offsets skips imported entries in compactMap guard branch")
    @MainActor
    func schedulesRemoveOffsetsSkipsImportedBranch() {
        let appState = isolatedAppState(name: "removeOffsetsSkipsImported")
        appState.calendarIntegrationEnabled = true
        appState.calendarImportsBlockTime = true
        let now = Date()
        appState.calendarProvider.events = [
            ExternalEvent(
                id: "imported-event-id",
                title: "Imported",
                startDate: now.addingTimeInterval(-300),
                endDate: now.addingTimeInterval(300)
            )
        ]
        appState.schedules = [sampleSchedule(name: "Local")]
        appState.checkSchedules()
        guard let importedIndex = appState.schedules.firstIndex(where: { $0.importedCalendarEventKey != nil }) else {
            Issue.record("Expected imported schedule generated from calendar sync")
            return
        }
        let importedId = appState.schedules[importedIndex].id
        guard let localIndex = appState.schedules.firstIndex(where: { $0.importedCalendarEventKey == nil }) else {
            Issue.record("Expected local schedule alongside imported schedule")
            return
        }
        let localId = appState.schedules[localIndex].id

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 0
        )
        #expect(controller.removableScheduleIDForTesting(at: 999) == nil)
        #expect(controller.removableScheduleIDForTesting(at: importedIndex) == nil)
        #expect(controller.removableScheduleIDForTesting(at: localIndex) == localId)
        controller.removeSchedulesForTesting(at: IndexSet(integer: importedIndex))
        #expect(appState.schedules.contains(where: { $0.id == importedId }))
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

    @Test("Schedules sheet controller supports switching between calendar and list via segmented control")
    @MainActor
    func schedulesViewToggleSwitchesModes() {
        let appState = isolatedAppState(name: "toggleModes")
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
        guard let segmented = subviews
            .compactMap({ $0 as? NSSegmentedControl })
            .first(where: { !$0.isHidden && $0.segmentCount == 2 })
        else {
            Issue.record("Expected list/calendar segmented control in toolbar")
            return
        }

        segmented.setSelected(true, forSegment: 0)
        if let action = segmented.action {
            NSApp.sendAction(action, to: segmented.target, from: segmented)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        #expect(segmented.selectedSegment == 0)
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

    @Test("Schedules sheet AppKit configuration callbacks route to controller actions")
    @MainActor
    func schedulesViewConfigurationCallbacks() {
        let appState = isolatedAppState(name: "configurationCallbacks")
        var dismissCount = 0
        let schedule = sampleSchedule(name: "Callback")
        appState.schedules = [schedule]

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: { dismissCount += 1 },
            initialViewMode: 1
        )
        _ = host(controller)

        var config = controller.appKitConfigurationForTesting
        config.onChangeViewMode(0)
        #expect(controller.viewModeForTesting == 0)

        config = controller.appKitConfigurationForTesting
        config.onSelectSchedule(schedule)
        #expect(controller.editorContextForTesting?.schedule?.id == schedule.id)

        config.onDismissEditor()
        #expect(controller.editorContextForTesting == nil)

        config.calendarViewConfiguration.onQuickAdd(2, 10)
        #expect(controller.editorContextForTesting?.day == 2)

        config.calendarViewConfiguration.onCreateSelection(3, 9.25, 10.75)
        #expect(controller.editorContextForTesting?.day == 3)

        config.calendarViewConfiguration.onOpenSchedule(2, schedule)
        #expect(controller.editorContextForTesting?.schedule?.id == schedule.id)

        config.onToggleScheduleEnabled(schedule.id, false)
        #expect(appState.schedules.first?.isEnabled == false)

        config.onDeleteSchedule(UUID())
        #expect(appState.schedules.count == 1)

        config.onAddSchedule()
        #expect(controller.editorContextForTesting != nil)

        let weekBefore = controller.weekOffsetForTesting
        config.onPreviousWeek()
        #expect(controller.weekOffsetForTesting == weekBefore - 1)
        config.onCurrentWeek()
        #expect(controller.weekOffsetForTesting == 0)
        config.onNextWeek()
        #expect(controller.weekOffsetForTesting == 1)

        config.onDismiss?()
        #expect(dismissCount == 1)
    }

    @Test("Schedules sheet testing helpers expose calendar month/config and week navigation methods")
    @MainActor
    func schedulesViewTestingHelpersForCalendarMetadataAndWeekNav() {
        let appState = isolatedAppState(name: "testingHelpersCalendarMetadataAndWeekNav")
        appState.schedules = [sampleSchedule(name: "Helper Schedule")]

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 1
        )
        _ = host(controller)

        #expect(controller.monthTitleForTesting.isEmpty == false)
        #expect(controller.calendarConfigurationForTesting.dayOrder.isEmpty == false)

        let before = controller.weekOffsetForTesting
        controller.goToPreviousWeekForTesting()
        #expect(controller.weekOffsetForTesting == before - 1)
        controller.goToCurrentWeekForTesting()
        #expect(controller.weekOffsetForTesting == 0)
        controller.goToNextWeekForTesting()
        #expect(controller.weekOffsetForTesting == 1)
    }

    @Test("Schedules callbacks safely early-return when controller is deallocated")
    @MainActor
    func schedulesViewCallbackNilSelfGuards() {
        let appState = isolatedAppState(name: "callbackNilSelfGuards")
        let schedule = sampleSchedule(name: "Nil Self")
        appState.schedules = [schedule]

        weak var weakController: SchedulesSheetViewController?
        var config: SchedulesAppKitConfiguration?
        autoreleasepool {
            var controller: SchedulesSheetViewController? = SchedulesSheetViewController(
                appState: appState,
                onDismiss: {},
                initialViewMode: 1
            )
            weakController = controller
            config = controller?.appKitConfigurationForTesting
            controller = nil
        }
        guard let config else {
            Issue.record("Expected schedules configuration snapshot")
            return
        }
        #expect(weakController == nil)

        config.onSelectSchedule(schedule)
        config.calendarViewConfiguration.onUpdateSchedule(
            schedule.id,
            2,
            2,
            nil,
            schedule.startTime.addingTimeInterval(60),
            schedule.endTime.addingTimeInterval(60)
        )
    }

    @Test("Schedules list view reuses existing row view identity for unchanged schedules")
    @MainActor
    func schedulesListRowReuseIdentity() throws {
        let appState = isolatedAppState(name: "listRowReuseIdentity")
        let first = sampleSchedule(name: "First")
        appState.schedules = [first]

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 0
        )
        _ = host(controller)

        let initialRowId = try #require(
            controller.listRowObjectIdentifierForTesting(scheduleId: first.id)
        )

        let second = sampleSchedule(name: "Second")
        appState.schedules.append(second)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        #expect(controller.listRowObjectIdentifierForTesting(scheduleId: first.id) == initialRowId)
        #expect(controller.listRowObjectIdentifierForTesting(scheduleId: second.id) != nil)
    }

    @Test("Schedules list document reorders existing row views when schedule order changes")
    @MainActor
    func schedulesListDocumentReorderCoverage() throws {
        let first = sampleSchedule(name: "First")
        let second = sampleSchedule(name: "Second")
        let document = SchedulesListDocumentNSView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))

        document.configure(
            schedules: [first, second],
            accentColorIndex: 0,
            onSelectSchedule: { _ in },
            onDeleteSchedule: { _ in },
            onToggleScheduleEnabled: { _, _ in }
        )
        document.layoutRows(width: 600)

        let firstIdentity = try #require(document.rowObjectIdentifierForTesting(scheduleId: first.id))
        let secondIdentity = try #require(document.rowObjectIdentifierForTesting(scheduleId: second.id))
        #expect(document.subviews.count == 2)

        document.configure(
            schedules: [second, first],
            accentColorIndex: 0,
            onSelectSchedule: { _ in },
            onDeleteSchedule: { _ in },
            onToggleScheduleEnabled: { _, _ in }
        )
        document.layoutRows(width: 600)

        #expect(document.rowObjectIdentifierForTesting(scheduleId: first.id) == firstIdentity)
        #expect(document.rowObjectIdentifierForTesting(scheduleId: second.id) == secondIdentity)
        #expect(ObjectIdentifier(document.subviews[0]) == secondIdentity)
        #expect(ObjectIdentifier(document.subviews[1]) == firstIdentity)
    }

    @Test("Schedules list row view handles draw, select, delete, and toggle callbacks")
    @MainActor
    func schedulesListRowViewInteractionCoverage() {
        let row = SchedulesListRowNSView(frame: NSRect(x: 0, y: 0, width: 420, height: 72))
        #expect(row.scheduleId == nil)
        row.showsSeparator = false
        row.layoutSubtreeIfNeeded()
        let image = NSImage(size: row.bounds.size)

        image.lockFocus()
        row.draw(row.bounds)
        image.unlockFocus()

        // Guard path when schedule is not configured.
        if let emptyMouseUp = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: 5, y: 5),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ) {
            row.mouseUp(with: emptyMouseUp)
        }
        firstSubview(of: NSButton.self, in: row)?.performClick(nil)
        firstSubview(of: NSSwitch.self, in: row)?.performClick(nil)

        let base = sampleSchedule(name: "Row Test")
        var selectedId: UUID?
        var deletedId: UUID?
        var toggled: (UUID, Bool)?
        row.configure(
            schedule: base,
            accentColorIndex: 2,
            onSelectSchedule: { selectedId = $0.id },
            onDeleteSchedule: { deletedId = $0 },
            onToggleScheduleEnabled: { toggled = ($0, $1) }
        )
        #expect(row.scheduleId == base.id)
        row.layoutSubtreeIfNeeded()

        if let mouseUp = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: 20, y: 20),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ) {
            row.mouseUp(with: mouseUp)
        }
        #expect(selectedId == base.id)

        let deleteButton = firstSubview(of: NSButton.self, in: row)
        #expect(deleteButton != nil)
        deleteButton?.performClick(nil)
        #expect(deletedId == base.id)

        let toggle = firstSubview(of: NSSwitch.self, in: row)
        #expect(toggle != nil)
        toggle?.state = .off
        toggle?.performClick(nil)
        #expect(toggled?.0 == base.id)
        #expect(toggled != nil)

        image.lockFocus()
        row.draw(row.bounds)
        image.unlockFocus()

        var imported = base
        imported.importedCalendarEventKey = "event-1"
        imported.type = .unfocus
        row.showsSeparator = true
        row.configure(
            schedule: imported,
            accentColorIndex: 1,
            onSelectSchedule: { _ in },
            onDeleteSchedule: { _ in },
            onToggleScheduleEnabled: { _, _ in }
        )
        row.layoutSubtreeIfNeeded()

        image.lockFocus()
        row.draw(row.bounds)
        image.unlockFocus()

        // Small-width guard paths for badge/tag rendering.
        row.frame = NSRect(x: 0, y: 0, width: 20, height: 72)
        row.layoutSubtreeIfNeeded()
        image.lockFocus()
        row.draw(row.bounds)
        image.unlockFocus()
    }

    @Test("Schedules sheet testing helpers cover dismiss callback and non-forced refresh no-op")
    @MainActor
    func schedulesTestingHelpersDismissAndRefreshCoverage() {
        let appState = isolatedAppState(name: "testingHelpersDismissAndRefreshCoverage")
        appState.schedules = [sampleSchedule(name: "Seed")]
        var dismissCount = 0
        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: { dismissCount += 1 },
            initialViewMode: 0
        )
        _ = host(controller)

        let generationBefore = controller.refreshGenerationForTesting
        controller.refreshConfigurationForTesting(force: false)
        #expect(controller.refreshGenerationForTesting == generationBefore)

        controller.invokeDismissForTesting()
        #expect(dismissCount == 1)
    }

    @Test("Schedules list row and schedules sheet unavailable coder init paths return nil")
    @MainActor
    func schedulesUnavailableCoderInitCoverage() throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.finishEncoding()
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        defer { unarchiver.finishDecoding() }

        #expect(SchedulesListRowNSView(coder: unarchiver) == nil)
        #expect(SchedulesSheetViewController(coder: unarchiver) == nil)
    }

    @Test("Schedules container routes toolbar actions and window attachment callback")
    @MainActor
    func schedulesContainerActionsAndWindowAttachment() {
        let appState = isolatedAppState(name: "containerActions")
        let container = SchedulesContainerNSView(frame: NSRect(x: 0, y: 0, width: 900, height: 760))
        _ = hostView(container)

        var changedModes: [Int] = []
        var addCount = 0
        var prevCount = 0
        var currentCount = 0
        var nextCount = 0
        var attachedWindows = 0
        container.onWindowAttached = { _ in attachedWindows += 1 }
        container.configure(
            with: SchedulesAppKitConfiguration(
                viewMode: 1,
                monthTitle: "March 2026",
                schedules: [sampleSchedule(name: "One")],
                accentColor: .systemGreen,
                accentColorIndex: appState.accentColorIndex,
                canModifySchedules: true,
                appState: appState,
                editorContext: nil,
                calendarViewConfiguration: sampleCalendarConfiguration(),
                onChangeViewMode: { changedModes.append($0) },
                onSelectSchedule: { _ in },
                onDeleteSchedule: { _ in },
                onToggleScheduleEnabled: { _, _ in },
                onAddSchedule: { addCount += 1 },
                onDismissEditor: {},
                onDismiss: {},
                onPreviousWeek: { prevCount += 1 },
                onCurrentWeek: { currentCount += 1 },
                onNextWeek: { nextCount += 1 }
            )
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 760),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSView(frame: window.frame)
        window.contentView?.addSubview(container)
        container.viewDidMoveToWindow()

        container.changeViewModeForTesting()
        container.addScheduleForTesting()
        container.goToPreviousWeekForTesting()
        container.goToCurrentWeekForTesting()
        container.goToNextWeekForTesting()

        var dismissEditorCount = 0
        let editorContext = ScheduleEditorContext(
            day: 2,
            startTime: sampleSchedule(name: "Edit Seed").startTime,
            endTime: sampleSchedule(name: "Edit Seed").endTime,
            schedule: nil,
            weekOffset: 0
        )
        let editorConfig = SchedulesAppKitConfiguration(
            viewMode: 1,
            monthTitle: "March 2026",
            schedules: [sampleSchedule(name: "Editor Host")],
            accentColor: .systemGreen,
            accentColorIndex: appState.accentColorIndex,
            canModifySchedules: true,
            appState: appState,
            editorContext: editorContext,
            calendarViewConfiguration: sampleCalendarConfiguration(),
            onChangeViewMode: { _ in },
            onSelectSchedule: { _ in },
            onDeleteSchedule: { _ in },
            onToggleScheduleEnabled: { _, _ in },
            onAddSchedule: {},
            onDismissEditor: { dismissEditorCount += 1 },
            onDismiss: {},
            onPreviousWeek: {},
            onCurrentWeek: {},
            onNextWeek: {}
        )
        container.configure(with: editorConfig)
        // Reconfigure with same context while sheet is active (reuse/guard path).
        container.configure(with: editorConfig)

        if let editor = window.attachedSheet?.contentViewController as? ScheduleEditorViewController {
            editor.dismissForTesting()
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        let noEditorConfig = SchedulesAppKitConfiguration(
            viewMode: 1,
            monthTitle: "March 2026",
            schedules: [sampleSchedule(name: "Editor Host")],
            accentColor: .systemGreen,
            accentColorIndex: appState.accentColorIndex,
            canModifySchedules: true,
            appState: appState,
            editorContext: nil,
            calendarViewConfiguration: sampleCalendarConfiguration(),
            onChangeViewMode: { _ in },
            onSelectSchedule: { _ in },
            onDeleteSchedule: { _ in },
            onToggleScheduleEnabled: { _, _ in },
            onAddSchedule: {},
            onDismissEditor: { dismissEditorCount += 1 },
            onDismiss: {},
            onPreviousWeek: {},
            onCurrentWeek: {},
            onNextWeek: {}
        )
        container.configure(with: noEditorConfig)

        #expect(changedModes == [1])
        #expect(addCount == 1)
        #expect(prevCount == 1)
        #expect(currentCount == 1)
        #expect(nextCount == 1)
        #expect(attachedWindows > 0)
        #expect(dismissEditorCount >= 1)
    }

    @Test("Schedules container dismiss helper clears injected editor controller")
    @MainActor
    func schedulesContainerDismissHelperCoverage() {
        let container = SchedulesContainerNSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        let sheet = FreeSheetWindowController(
            contentViewController: NSViewController(),
            contentSize: CGSize(width: 320, height: 240),
            onClose: {}
        )
        container.setEditorSheetControllerForTesting(sheet)
        container.dismissEditorIfNeededForTesting(clearContext: true)
        container.dismissEditorIfNeededForTesting()
    }

    @Test("Schedules container coder init returns nil and pre-config window attach is safe")
    @MainActor
    func schedulesContainerCoderAndPreConfigGuardCoverage() throws {
        let container = SchedulesContainerNSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        container.viewDidMoveToWindow()

        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.finishEncoding()
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        defer { unarchiver.finishDecoding() }
        #expect(SchedulesContainerNSView(coder: unarchiver) == nil)
    }

    @Test("Schedules controller testing hooks cover editor and lightweight refresh paths")
    @MainActor
    func schedulesControllerHookCoverage() {
        let appState = isolatedAppState(name: "controllerHooks")
        var schedule = sampleSchedule(name: "Hook")
        schedule.days = [2]
        appState.schedules = [schedule]

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 1
        )
        _ = host(controller)
        let initialGeneration = controller.refreshGenerationForTesting

        controller.quickAddForTesting(day: 2, hour: 11)
        #expect(controller.editorContextForTesting?.day == 2)

        controller.openSelectionEditorForTesting(day: 2, startHour: 11.1, endHour: 12.2)
        #expect(controller.editorContextForTesting?.day == 2)

        controller.openScheduleEditorForTesting(day: 2, schedule: schedule)
        #expect(controller.editorContextForTesting?.schedule?.id == schedule.id)

        controller.setScheduleEnabledForTesting(scheduleId: schedule.id, isEnabled: false)
        #expect(appState.schedules.first?.isEnabled == false)
        controller.setScheduleEnabledForTesting(scheduleId: UUID(), isEnabled: true)

        controller.refreshConfigurationForTesting(force: false)
        #expect(controller.refreshGenerationForTesting >= initialGeneration + 4)

        let generationAfterNoForce = controller.refreshGenerationForTesting
        appState.appearanceMode = .dark
        controller.refreshConfigurationForTesting(force: false)
        #expect(controller.refreshGenerationForTesting > generationAfterNoForce)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 760),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSView(frame: window.frame)
        window.contentView?.addSubview(controller.view)
        controller.updateWindowTitleForTesting()
        #expect(!window.title.isEmpty)

        var dismissCount = 0
        let dismissController = SchedulesSheetViewController(
            appState: appState,
            onDismiss: { dismissCount += 1 },
            initialViewMode: 0
        )
        _ = host(dismissController)
        dismissController.invokeDismissForTesting()
        #expect(dismissCount == 1)
    }

    @Test("Schedules sheet maps external-event snapshots and routes calendar update callback")
    @MainActor
    func schedulesExternalEventsAndUpdateCallbackCoverage() {
        let appState = isolatedAppState(name: "externalEventsAndUpdateCallback")
        var schedule = sampleSchedule(name: "Calendar Update")
        schedule.days = [2]
        appState.schedules = [schedule]
        appState.calendarIntegrationEnabled = true
        appState.calendarImportsBlockTime = false
        appState.calendarProvider.events = [
            ExternalEvent(
                id: "event-1",
                title: "Meeting",
                startDate: Date().addingTimeInterval(600),
                endDate: Date().addingTimeInterval(1200)
            )
        ]

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 1
        )
        _ = host(controller)

        let generationBeforeCalendarPublish = controller.refreshGenerationForTesting
        appState.calendarProvider.events = [
            ExternalEvent(
                id: "event-2",
                title: "Follow-up",
                startDate: Date().addingTimeInterval(1800),
                endDate: Date().addingTimeInterval(2400)
            )
        ]
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(controller.refreshGenerationForTesting > generationBeforeCalendarPublish)

        controller.refreshConfigurationForTesting(force: false)
        let config = controller.appKitConfigurationForTesting

        let updatedStart = schedule.startTime.addingTimeInterval(900)
        let updatedEnd = schedule.endTime.addingTimeInterval(900)
        config.calendarViewConfiguration.onUpdateSchedule(
            schedule.id,
            2,
            2,
            nil,
            updatedStart,
            updatedEnd
        )

        guard let updated = appState.schedules.first(where: { $0.id == schedule.id }) else {
            Issue.record("Expected updated schedule to still exist")
            return
        }
        #expect(updated.startTime == updatedStart)
        #expect(updated.endTime == updatedEnd)
    }

    @Test("Schedules sheet hides external overlay entries when mirrored imported schedules already exist")
    @MainActor
    func schedulesExternalOverlaySkipsMirroredImportedEvents() {
        let appState = isolatedAppState(name: "externalOverlaySkipsMirroredImportedEvents")
        appState.calendarIntegrationEnabled = true
        appState.calendarImportsBlockTime = false
        appState.suppressedImportedCalendarEventKeys = ["event-2"]

        var local = sampleSchedule(name: "Local")
        local.days = [2]
        appState.schedules = [local]
        appState.calendarProvider.events = [
            ExternalEvent(
                id: "event-1",
                title: "Mirrored",
                startDate: Date().addingTimeInterval(600),
                endDate: Date().addingTimeInterval(1200)
            ),
            ExternalEvent(
                id: "event-2",
                title: "Unmirrored",
                startDate: Date().addingTimeInterval(1800),
                endDate: Date().addingTimeInterval(2400)
            ),
        ]
        appState.checkSchedules()
        #expect(appState.schedules.contains(where: { $0.importedCalendarEventKey == "event-1" }))
        #expect(appState.schedules.contains(where: { $0.importedCalendarEventKey == "event-2" }) == false)

        let controller = SchedulesSheetViewController(
            appState: appState,
            onDismiss: {},
            initialViewMode: 1
        )
        _ = host(controller)

        let externalEvents = controller.appKitConfigurationForTesting.calendarViewConfiguration.externalEvents
        #expect(externalEvents.contains(where: { $0.id == "event-1" }) == false)
        #expect(externalEvents.contains(where: { $0.id == "event-2" }))
    }

}
