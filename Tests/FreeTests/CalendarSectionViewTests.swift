import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct CalendarSectionViewTests {
    private final class TestModalAlert: NSAlert {
        override func runModal() -> NSApplication.ModalResponse {
            .alertFirstButtonReturn
        }
    }

    private func isolatedAppState(name: String) -> AppState {
        let suite = "CalendarSectionViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, calendar: MockCalendarManager(), isTesting: true)
    }

    @MainActor
    private func host(
        _ controller: NSViewController,
        size: CGSize = CGSize(width: 560, height: 760)
    ) -> NSView {
        controller.loadViewIfNeeded()
        controller.view.frame = NSRect(origin: .zero, size: size)
        controller.view.layoutSubtreeIfNeeded()
        controller.view.displayIfNeeded()
        return controller.view
    }

    private func allSubviews(in view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { allSubviews(in: $0) }
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
        for sub in view.subviews {
            values.append(contentsOf: visibleText(in: sub))
        }
        return values
    }

    private func textField(
        withPlaceholder placeholder: String,
        in root: NSView
    ) -> NSTextField? {
        allSubviews(in: root).compactMap { $0 as? NSTextField }.first {
            $0.placeholderString == placeholder
        }
    }

    private func buttons(
        titled title: String,
        in root: NSView
    ) -> [NSButton] {
        allSubviews(in: root).compactMap { $0 as? NSButton }.filter { $0.title == title }
    }

    private func tableViews(in root: NSView) -> [NSTableView] {
        allSubviews(in: root).compactMap { $0 as? NSTableView }
    }

    private func popupButtons(in root: NSView) -> [NSPopUpButton] {
        allSubviews(in: root).compactMap { $0 as? NSPopUpButton }
    }

    private func triggerTableSelectionAction(_ tableView: NSTableView) {
        guard let action = tableView.action else { return }
        _ = (tableView.target as AnyObject?)?.perform(action, with: tableView)
    }

    @Test("Calendar section renders integration and import-rules controls")
    @MainActor
    func calendarSectionRender() {
        let appState = isolatedAppState(name: "render")
        let controller = CalendarSectionViewController(appState: appState)
        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(texts.contains("Calendar"))
        #expect(texts.contains("Integration"))
        #expect(texts.contains("Enable Calendar Integration"))
        #expect(texts.contains("Calendar Imports Block Time"))
        #expect(texts.contains("Imported Schedules Allowed List"))
        #expect(texts.contains("Resync Imported Schedules"))
        #expect(texts.contains("Import Rules"))
        #expect(texts.contains("Focus Title Rules"))
        #expect(texts.contains("Break Title Rules"))
    }

    @Test("Calendar section testing hooks update integration state")
    @MainActor
    func calendarSectionToggleHooks() {
        let appState = isolatedAppState(name: "toggleHooks")
        let controller = CalendarSectionViewController(appState: appState)
        _ = host(controller)

        controller.setWeekStartsMondayForTesting(true)
        #expect(appState.weekStartsOnMonday)
        controller.setWeekStartsMondayForTesting(false)
        #expect(appState.weekStartsOnMonday == false)

        controller.setCalendarIntegrationForTesting(true)
        #expect(appState.calendarIntegrationEnabled)
        controller.setCalendarImportsForTesting(true)
        #expect(appState.calendarImportsBlockTime)
        controller.setCalendarImportsForTesting(false)
        #expect(appState.calendarImportsBlockTime == false)
        controller.setCalendarIntegrationForTesting(false)
        #expect(appState.calendarIntegrationEnabled == false)

        controller.setCalendarIntegrationForTesting(true)
        controller.setImportedScheduleRuleSetSelectionIndexForTesting(0)
        #expect(appState.calendarImportedScheduleRuleSetId == nil)
    }

    @Test("Calendar section imported allowed-list selector binds to app state and follows integration lock")
    @MainActor
    func calendarSectionImportedRuleSetSelection() {
        let appState = isolatedAppState(name: "importedRuleSetSelection")
        let base = appState.ruleSets.first ?? RuleSet.defaultSet()
        let selected = RuleSet(name: "Imported List", urls: ["calendar.example"])
        appState.ruleSets = [base, selected]
        appState.calendarIntegrationEnabled = true

        let controller = CalendarSectionViewController(appState: appState)
        let hosted = host(controller)
        guard let popup = popupButtons(in: hosted).first(where: { $0.itemTitles.contains("Use Active Allowed List") }) else {
            Issue.record("Expected imported schedules allowed-list popup")
            return
        }

        #expect(popup.itemTitles.contains("Imported List"))
        controller.setImportedScheduleRuleSetSelectionIndexForTesting(2)
        #expect(appState.calendarImportedScheduleRuleSetId == selected.id)

        controller.setCalendarIntegrationForTesting(false)
        #expect(popup.isEnabled == false)
    }

    @Test("Calendar section add/remove rules covers parsing, dedupe and selection")
    @MainActor
    func calendarSectionRuleActions() {
        let appState = isolatedAppState(name: "ruleActions")
        appState.calendarIntegrationEnabled = true
        appState.calendarImportFocusTitleRules = ["existing"]
        appState.calendarImportBreakTitleRules = ["pause"]

        let controller = CalendarSectionViewController(appState: appState)
        let hosted = host(controller)

        guard
            let focusField = textField(withPlaceholder: "Add focus title rule...", in: hosted),
            let breakField = textField(withPlaceholder: "Add break title rule...", in: hosted)
        else {
            Issue.record("Expected calendar rule input fields")
            return
        }

        let addButtons = buttons(titled: "Add", in: hosted)
        let removeButtons = buttons(titled: "Remove Selected", in: hosted)
        let tables = tableViews(in: hosted)
        guard addButtons.count >= 2, removeButtons.count >= 2, tables.count >= 2 else {
            Issue.record("Expected focus/break add/remove buttons and tables")
            return
        }

        focusField.stringValue = "  alpha, Beta ; existing \n alpha  "
        addButtons[0].performClick(nil)
        #expect(appState.calendarImportFocusTitleRules == ["existing", "alpha", "Beta"])
        #expect(focusField.stringValue.isEmpty)

        breakField.stringValue = " lunch ; pause \n LUNCH "
        addButtons[1].performClick(nil)
        #expect(appState.calendarImportBreakTitleRules == ["pause", "lunch"])
        #expect(breakField.stringValue.isEmpty)

        // Empty parse branch.
        focusField.stringValue = "  , ; \n "
        addButtons[0].performClick(nil)
        #expect(appState.calendarImportFocusTitleRules == ["existing", "alpha", "Beta"])

        // Focus remove branch.
        tables[0].selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        triggerTableSelectionAction(tables[0])
        removeButtons[0].performClick(nil)
        #expect(appState.calendarImportFocusTitleRules == ["existing", "Beta"])

        // Break remove branch.
        tables[1].selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        triggerTableSelectionAction(tables[1])
        removeButtons[1].performClick(nil)
        #expect(appState.calendarImportBreakTitleRules == ["pause"])

        // Guard branch: no selection.
        removeButtons[1].performClick(nil)
        #expect(appState.calendarImportBreakTitleRules == ["pause"])
    }

    @Test("Calendar section disables rule actions when integration is off and lock path is exposed")
    @MainActor
    func calendarSectionDisabledControls() {
        let appState = isolatedAppState(name: "disabledControls")
        appState.calendarIntegrationEnabled = false
        appState.isBlocking = true
        appState.isUnblockable = true

        let controller = CalendarSectionViewController(appState: appState)
        let hosted = host(controller)
        let addButtons = buttons(titled: "Add", in: hosted)
        let removeButtons = buttons(titled: "Remove Selected", in: hosted)
        guard addButtons.count >= 2, removeButtons.count >= 2 else {
            Issue.record("Expected disabled add/remove buttons")
            return
        }

        #expect(addButtons[0].isEnabled == false)
        #expect(addButtons[1].isEnabled == false)
        #expect(removeButtons[0].isEnabled == false)
        #expect(removeButtons[1].isEnabled == false)
        #expect(controller.calendarControlsLockedForTesting)
    }

    @Test("Calendar section resync requests access and falls back to permission alert in test runtime")
    @MainActor
    func calendarSectionResyncUnauthorizedPresentsFallback() {
        defer { CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting() }
        let appState = isolatedAppState(name: "resyncUnauthorizedPresentsFallback")
        guard let calendar = appState.calendarProvider as? MockCalendarManager else {
            Issue.record("Expected MockCalendarManager")
            return
        }
        calendar.isAuthorized = false

        var alertRunCount = 0
        CalendarSectionViewController.scheduleAfter = { _, work in work() }
        CalendarSectionViewController.makeCalendarPermissionAlert = { NSAlert() }
        CalendarSectionViewController.runCalendarPermissionAlert = { _ in
            alertRunCount += 1
            return .alertSecondButtonReturn
        }

        let controller = CalendarSectionViewController(appState: appState)
        _ = host(controller)
        controller.resyncImportedSchedulesForTesting()

        #expect(calendar.requestAccessCallCount == 1)
        #expect(alertRunCount == 1)
    }

    @Test("Calendar section permission fallback scheduler guards pending and restored-authorization branches")
    @MainActor
    func calendarSectionPermissionFallbackSchedulerGuards() {
        defer { CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting() }
        let originalEnv = getenv("XCTestConfigurationFilePath").map { String(cString: $0) }
        unsetenv("XCTestConfigurationFilePath")
        defer {
            if let originalEnv {
                setenv("XCTestConfigurationFilePath", originalEnv, 1)
            } else {
                unsetenv("XCTestConfigurationFilePath")
            }
        }

        let appState = isolatedAppState(name: "permissionFallbackSchedulerGuards")
        guard let calendar = appState.calendarProvider as? MockCalendarManager else {
            Issue.record("Expected MockCalendarManager")
            return
        }
        calendar.isAuthorized = false

        var scheduledClosures: [() -> Void] = []
        var alertRunCount = 0
        CalendarSectionViewController.scheduleAfter = { _, work in
            scheduledClosures.append(work)
        }
        CalendarSectionViewController.runCalendarPermissionAlert = { _ in
            alertRunCount += 1
            return .alertSecondButtonReturn
        }

        let controller = CalendarSectionViewController(appState: appState)
        _ = host(controller)

        controller.resyncImportedSchedulesForTesting()
        controller.resyncImportedSchedulesForTesting()
        #expect(scheduledClosures.count == 1)
        #expect(alertRunCount == 0)

        calendar.isAuthorized = true
        scheduledClosures[0]()
        #expect(alertRunCount == 0)

        calendar.isAuthorized = false
        controller.resyncImportedSchedulesForTesting()
        #expect(scheduledClosures.count == 2)
    }

    @Test("Calendar section permission fallback immediate test-runtime branch presents alert")
    @MainActor
    func calendarSectionPermissionFallbackImmediateTestRuntimeBranch() {
        defer { CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting() }
        let originalEnv = getenv("XCTestConfigurationFilePath").map { String(cString: $0) }
        setenv("XCTestConfigurationFilePath", "1", 1)
        defer {
            if let originalEnv {
                setenv("XCTestConfigurationFilePath", originalEnv, 1)
            } else {
                unsetenv("XCTestConfigurationFilePath")
            }
        }

        let appState = isolatedAppState(name: "permissionFallbackImmediateTestRuntimeBranch")
        guard let calendar = appState.calendarProvider as? MockCalendarManager else {
            Issue.record("Expected MockCalendarManager")
            return
        }
        calendar.isAuthorized = false

        var alertRunCount = 0
        CalendarSectionViewController.runCalendarPermissionAlert = { _ in
            alertRunCount += 1
            return .alertSecondButtonReturn
        }

        let controller = CalendarSectionViewController(appState: appState)
        _ = host(controller)
        controller.resyncImportedSchedulesForTesting()
        #expect(alertRunCount == 1)
    }

    @Test("Calendar section permission alert open-settings path handles valid and invalid URLs")
    @MainActor
    func calendarSectionPermissionAlertOpenSettings() {
        defer { CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting() }
        let appState = isolatedAppState(name: "permissionAlertOpenSettings")
        let controller = CalendarSectionViewController(appState: appState)
        _ = host(controller)

        var openedURLs: [URL] = []
        CalendarSectionViewController.workspaceURLOpener = { url in
            openedURLs.append(url)
        }
        CalendarSectionViewController.makeCalendarPermissionAlert = { NSAlert() }
        CalendarSectionViewController.runCalendarPermissionAlert = { _ in .alertFirstButtonReturn }

        CalendarSectionViewController.calendarPrivacySettingsURLString = "invalid"
        controller.invokeCalendarPermissionAlertForTesting()
        #expect(openedURLs.isEmpty)

        CalendarSectionViewController.calendarPrivacySettingsURLString =
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        controller.invokeCalendarPermissionAlertForTesting()
        #expect(openedURLs.count == 1)
    }

    @Test("Calendar section static opener/scheduler hooks cover default getter and setter paths")
    @MainActor
    func calendarSectionStaticHookCoverage() {
        defer { CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting() }

        CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting()
        CalendarSectionViewController.platformWorkspaceURLOpener(URL(string: "x-free-test://noop")!)

        var platformOpenCount = 0
        CalendarSectionViewController.platformWorkspaceURLOpener = { _ in
            platformOpenCount += 1
        }
        CalendarSectionViewController.workspaceURLOpener(URL(string: "https://example.com")!)
        #expect(platformOpenCount == 1)

        var customOpenCount = 0
        CalendarSectionViewController.openCalendarPrivacySettings = {
            customOpenCount += 1
        }
        CalendarSectionViewController.openCalendarPrivacySettings()
        #expect(customOpenCount == 1)

        CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting()
        let scheduler = CalendarSectionViewController.scheduleAfter
        var fired = false
        scheduler(0) { fired = true }
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        _ = fired
    }

    @Test("Calendar section platform workspace opener covers x-free-test guard and native open path")
    @MainActor
    func calendarSectionPlatformWorkspaceOpenerCoverage() {
        defer { CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting() }

        CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting()
        var nativeOpened: [URL] = []
        CalendarSectionViewController.isRunningInTestProcess = { false }
        CalendarSectionViewController.nativeWorkspaceURLOpener = { nativeOpened.append($0) }

        CalendarSectionViewController.platformWorkspaceURLOpener(URL(string: "x-free-test://noop")!)
        #expect(nativeOpened.isEmpty)

        let openURL = URL(string: "https://example.com/calendar")!
        CalendarSectionViewController.platformWorkspaceURLOpener(openURL)
        #expect(nativeOpened == [openURL])
    }

    @Test("Calendar section default workspace helpers expose callable detector and opener closures")
    @MainActor
    func calendarSectionDefaultWorkspaceHelperGettersCoverage() {
        defer { CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting() }

        CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting()
        let detector = CalendarSectionViewController.isRunningInTestProcess
        _ = detector()

        // Getter-only coverage for default native opener closure creation.
        _ = CalendarSectionViewController.nativeWorkspaceURLOpener
    }

    @Test("Calendar section resync authorized path triggers imported schedule rebuild")
    @MainActor
    func calendarSectionResyncAuthorizedPath() {
        let appState = isolatedAppState(name: "resyncAuthorizedPath")
        guard let calendar = appState.calendarProvider as? MockCalendarManager else {
            Issue.record("Expected MockCalendarManager")
            return
        }
        appState.calendarIntegrationEnabled = true
        calendar.isAuthorized = true
        calendar.events = [
            ExternalEvent(
                id: "resync-auth",
                title: "Calendar Focus",
                startDate: Date().addingTimeInterval(60),
                endDate: Date().addingTimeInterval(660)
            )
        ]

        let controller = CalendarSectionViewController(appState: appState)
        _ = host(controller)
        controller.resyncImportedSchedulesForTesting()

        #expect(appState.schedules.contains(where: { $0.importedCalendarEventKey == "resync-auth" }))
    }

    @Test("Calendar section field action handlers and empty-selection remove guards are covered")
    @MainActor
    func calendarSectionFieldActionAndEmptyRemoveGuards() {
        let appState = isolatedAppState(name: "fieldActionAndEmptyRemoveGuards")
        appState.calendarIntegrationEnabled = true
        appState.calendarImportFocusTitleRules = ["focus-1"]
        appState.calendarImportBreakTitleRules = ["break-1"]

        let controller = CalendarSectionViewController(appState: appState)
        let hosted = host(controller)
        guard
            let focusField = textField(withPlaceholder: "Add focus title rule...", in: hosted),
            let breakField = textField(withPlaceholder: "Add break title rule...", in: hosted)
        else {
            Issue.record("Expected calendar rule fields")
            return
        }

        // Trigger add-from-field ObjC actions.
        focusField.stringValue = "focus-2"
        if let action = focusField.action {
            _ = (focusField.target as AnyObject?)?.perform(action, with: focusField)
        }
        breakField.stringValue = "break-2"
        if let action = breakField.action {
            _ = (breakField.target as AnyObject?)?.perform(action, with: breakField)
        }
        #expect(appState.calendarImportFocusTitleRules.contains("focus-2"))
        #expect(appState.calendarImportBreakTitleRules.contains("break-2"))

        // Trigger remove guards with no selection.
        let removeButtons = buttons(titled: "Remove Selected", in: hosted)
        guard removeButtons.count >= 2 else {
            Issue.record("Expected remove buttons")
            return
        }
        if let focusAction = removeButtons[0].action {
            _ = (removeButtons[0].target as AnyObject?)?.perform(focusAction, with: removeButtons[0])
        }
        if let breakAction = removeButtons[1].action {
            _ = (removeButtons[1].target as AnyObject?)?.perform(breakAction, with: removeButtons[1])
        }
        #expect(appState.calendarImportFocusTitleRules.contains("focus-1"))
        #expect(appState.calendarImportBreakTitleRules.contains("break-1"))
    }

    @Test("Calendar section table callbacks cover weak-self nil and out-of-bounds rule guards")
    @MainActor
    func calendarSectionTableCallbackGuards() {
        var controller: CalendarSectionViewController? = CalendarSectionViewController(
            appState: isolatedAppState(name: "tableCallbackGuards")
        )
        let hosted = host(controller!)
        let tables = tableViews(in: hosted)
        guard tables.count >= 2 else {
            Issue.record("Expected two calendar rules tables")
            return
        }

        let focusDataSource = tables[0].dataSource
        let focusDelegate = tables[0].delegate
        let breakDataSource = tables[1].dataSource
        let breakDelegate = tables[1].delegate
        #expect(focusDataSource?.numberOfRows?(in: tables[0]) ?? -1 >= 0)
        _ = focusDelegate?.tableView?(tables[0], viewFor: tables[0].tableColumns.first, row: 999)
        _ = breakDelegate?.tableView?(tables[1], viewFor: tables[1].tableColumns.first, row: 999)

        weak let weakController = controller
        controller = nil
        #expect(weakController == nil)

        // weak-self guard paths inside numberOfRules/ruleAt closures.
        #expect(focusDataSource?.numberOfRows?(in: tables[0]) == 0)
        _ = focusDelegate?.tableView?(tables[0], viewFor: tables[0].tableColumns.first, row: 0)
        #expect(breakDataSource?.numberOfRows?(in: tables[1]) == 0)
        _ = breakDelegate?.tableView?(tables[1], viewFor: tables[1].tableColumns.first, row: 0)
    }

    @Test("Calendar section permission fallback closure handles deallocated controller safely")
    @MainActor
    func calendarSectionPermissionFallbackNilSelfGuard() {
        defer { CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting() }
        let originalEnv = getenv("XCTestConfigurationFilePath").map { String(cString: $0) }
        unsetenv("XCTestConfigurationFilePath")
        defer {
            if let originalEnv {
                setenv("XCTestConfigurationFilePath", originalEnv, 1)
            } else {
                unsetenv("XCTestConfigurationFilePath")
            }
        }

        let appState = isolatedAppState(name: "permissionFallbackNilSelfGuard")
        guard let calendar = appState.calendarProvider as? MockCalendarManager else {
            Issue.record("Expected MockCalendarManager")
            return
        }
        calendar.isAuthorized = false

        var scheduledClosures: [() -> Void] = []
        CalendarSectionViewController.scheduleAfter = { _, work in
            scheduledClosures.append(work)
        }

        var controller: CalendarSectionViewController? = CalendarSectionViewController(appState: appState)
        _ = host(controller!)
        controller?.resyncImportedSchedulesForTesting()
        #expect(scheduledClosures.count == 1)

        weak let weakController = controller
        controller = nil
        #expect(weakController == nil)

        // Covers guard-let-self early return in scheduled fallback closure.
        scheduledClosures[0]()
    }

    @Test("Calendar section observation callback reloads view on settings signature changes")
    @MainActor
    func calendarSectionObservationReloadPath() {
        let appState = isolatedAppState(name: "observationReloadPath")
        let controller = CalendarSectionViewController(appState: appState)
        let hosted = host(controller)
        guard
            let integrationNotice = allSubviews(in: hosted)
                .compactMap({ $0 as? NSTextField })
                .first(where: { $0.stringValue == "Enable Calendar Integration to use calendar title rules." })
        else {
            Issue.record("Expected integration notice label")
            return
        }

        #expect(integrationNotice.isHidden == false)
        appState.calendarIntegrationEnabled = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        #expect(integrationNotice.isHidden)
    }

    @MainActor
    @Test("Calendar section default alert hooks cover NSAlert runModal fallback and XCTest guard")
    func calendarSectionDefaultAlertHooksCoverage() {
        defer {
            _ = setenv("XCTestConfigurationFilePath", "1", 1)
            CalendarSectionViewController.resetCalendarPermissionAlertHooksForTesting()
        }

        unsetenv("XCTestConfigurationFilePath")
        _ = CalendarSectionViewController.makeCalendarPermissionAlert()
        #expect(
            CalendarSectionViewController.runCalendarPermissionAlert(TestModalAlert())
                == .alertFirstButtonReturn
        )

        _ = setenv("XCTestConfigurationFilePath", "1", 1)
        #expect(
            CalendarSectionViewController.runCalendarPermissionAlert(TestModalAlert())
                == .alertSecondButtonReturn
        )
    }
}
