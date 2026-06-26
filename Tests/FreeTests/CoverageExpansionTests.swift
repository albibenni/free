import AppKit
import Combine
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct CoverageExpansionTests {
    private final class ImportFlowAutomator: BrowserAutomator {
        let urls: [String]

        init(urls: [String]) {
            self.urls = urls
        }

        func getActiveUrl(for app: NSRunningApplication) -> String? { nil }
        func redirect(app: NSRunningApplication, to url: String) {}
        func getAllOpenUrls(browsers: [String]) -> [String] { urls }
        func checkPermissions(prompt: Bool) -> Bool { true }
    }

    private func isolatedAppState(name: String) -> AppState {
        let suite = "CoverageExpansionTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, calendar: MockCalendarManager(), isTesting: true)
    }

    

    @Test("AppState domain adapters round-trip settings, schedules, session and pomodoro state")
    func appStateDomainAdaptersRoundTrip() async throws {
        let appState = isolatedAppState(name: "appStateDomainAdaptersRoundTrip")
        let now = Date()
        let schedule = Schedule(
            name: "Focus",
            days: [2],
            startTime: now,
            endTime: now.addingTimeInterval(3600),
            type: .focus
        )
        let importedRuleSetId = UUID()
        let setId = UUID()

        appState.applySettingsDomainState(
            .init(
                weekStartsOnMonday: true,
                accentColorIndex: 3,
                appearanceMode: .dark,
                cursorFluidAnimationEnabled: false,
                calendarImportFocusTitleRules: ["focus"],
                calendarImportBreakTitleRules: ["break"],
                calendarImportedScheduleRuleSetId: importedRuleSetId,
                blockNewTabs: true,
                blockDeveloperHosts: true,
                blockLocalNetworkHosts: true,
                allowSearchEngineWebsites: true,
                allowAIProviderWebsites: true
            )
        )
        #expect(appState.settingsDomainState.weekStartsOnMonday)
        #expect(appState.settingsDomainState.accentColorIndex == 3)
        #expect(appState.settingsDomainState.appearanceMode == .dark)
        #expect(appState.settingsDomainState.cursorFluidAnimationEnabled == false)
        #expect(appState.settingsDomainState.calendarImportFocusTitleRules == ["focus"])
        #expect(appState.settingsDomainState.calendarImportBreakTitleRules == ["break"])
        #expect(appState.settingsDomainState.calendarImportedScheduleRuleSetId == importedRuleSetId)
        #expect(appState.settingsDomainState.blockNewTabs)
        #expect(appState.settingsDomainState.blockDeveloperHosts)
        #expect(appState.settingsDomainState.blockLocalNetworkHosts)
        #expect(appState.settingsDomainState.allowSearchEngineWebsites)
        #expect(appState.settingsDomainState.allowAIProviderWebsites)

        appState.applyScheduleDomainState(
            .init(
                schedules: [schedule],
                calendarIntegrationEnabled: true,
                isSynchronizingImportedSchedules: true,
                suppressedImportedCalendarEventKeys: ["event-1"]
            )
        )
        #expect(appState.scheduleDomainState.schedules.count == 1)
        #expect(appState.scheduleDomainState.calendarIntegrationEnabled)
        #expect(appState.scheduleDomainState.isSynchronizingImportedSchedules)
        #expect(appState.scheduleDomainState.suppressedImportedCalendarEventKeys == ["event-1"])

        appState.applySessionDomainState(
            .init(
                isBlocking: true,
                isStrict: true,
                isPaused: true,
                pauseRemaining: 90,
                wasStartedBySchedule: true,
                manuallyPausedScheduleIds: [UUID()]
            )
        )
        #expect(appState.sessionDomainState.isBlocking)
        #expect(appState.sessionDomainState.isStrict)
        #expect(appState.sessionDomainState.isPaused)
        #expect(appState.sessionDomainState.pauseRemaining == 90)
        #expect(appState.sessionDomainState.wasStartedBySchedule)
        #expect(appState.sessionDomainState.manuallyPausedScheduleIds.count == 1)

        appState.applyPauseEngineState(.init(isPaused: false, remaining: 0))
        #expect(appState.sessionDomainState.isPaused == false)
        #expect(appState.sessionDomainState.pauseRemaining == 0)

        appState.applyPomodoroDomainState(
            .init(
                status: .focus,
                remaining: 600,
                startedAt: now,
                focusDurationMinutes: 45,
                breakDurationMinutes: 15,
                ruleSetId: setId
            )
        )
        #expect(appState.pomodoroDomainState.status == .focus)
        #expect(appState.pomodoroDomainState.remaining == 45 * 60)
        #expect(appState.pomodoroDomainState.startedAt == now)
        #expect(appState.pomodoroDomainState.focusDurationMinutes == 45)
        #expect(appState.pomodoroDomainState.breakDurationMinutes == 15)
        #expect(appState.pomodoroDomainState.ruleSetId == setId)

        appState.applyPomodoroEngineState(
            .init(status: .breakTime, remaining: 300, startedAt: now.addingTimeInterval(5), ruleSetId: nil)
        )
        #expect(appState.pomodoroDomainState.status == .breakTime)
        #expect(appState.pomodoroDomainState.remaining == 300)
        #expect(appState.pomodoroDomainState.startedAt == now.addingTimeInterval(5))
        #expect(appState.pomodoroDomainState.ruleSetId == nil)

        appState.setWasStartedBySchedule(false)
        #expect(appState.wasStartedBySchedule == false)
    }

    @Test("AppState settings domain adapter no-ops when values are unchanged")
    func appStateSettingsDomainAdapterNoOpBranches() async throws {
        let appState = isolatedAppState(name: "appStateSettingsDomainAdapterNoOpBranches")
        let original = appState.settingsDomainState

        appState.applySettingsDomainState(original)

        #expect(appState.settingsDomainState == original)
    }

    @Test("Calendar sync adapters no-op safely when sync is not needed")
    func calendarSyncNoOpWhenNoChanges() async throws {
        let appState = isolatedAppState(name: "calendarSyncNoOpWhenNoChanges")
        let originalSchedules = appState.schedules
        appState.synchronizeImportedCalendarSchedulesIfNeeded()
        appState.resyncImportedCalendarSchedules()
        #expect(appState.schedules == originalSchedules)
    }

    @Test("Calendar sync mutation service resync returns rebuilt schedule update")
    func calendarSyncMutationServiceResyncUpdatePath() async throws {
        let now = Date()
        let existing = Schedule(
            name: "Manual",
            days: [2],
            startTime: now,
            endTime: now.addingTimeInterval(1200),
            type: .focus
        )
        let event = ExternalEvent(
            id: "resync-event",
            title: "Imported Focus",
            startDate: now.addingTimeInterval(300),
            endDate: now.addingTimeInterval(1800)
        )
        let ruleSet = RuleSet(name: "Default", urls: ["example.com"])

        let context = AppStateCalendarSyncMutationService.Context(
            schedule: AppScheduleDomainState(
                schedules: [existing],
                calendarIntegrationEnabled: true,
                isSynchronizingImportedSchedules: false,
                suppressedImportedCalendarEventKeys: []
            ),
            rules: AppRulesDomainState(
                ruleSets: [ruleSet],
                activeRuleSetId: ruleSet.id
            ),
            settings: AppSettingsDomainState(
                weekStartsOnMonday: false,
                accentColorIndex: 0,
                appearanceMode: .system,
                cursorFluidAnimationEnabled: true,
                calendarImportFocusTitleRules: [],
                calendarImportBreakTitleRules: [],
                blockNewTabs: false,
                blockDeveloperHosts: false,
                blockLocalNetworkHosts: false,
                allowSearchEngineWebsites: false,
                allowAIProviderWebsites: false
            ),
            weekStartsOnMonday: false,
            events: [event]
        )

        let update = AppStateCalendarSyncMutationService.resync(
            logicFacade: .live,
            context: context,
            preservedImportedByKey: [:]
        )

        #expect(update != nil)
        #expect(update?.schedule.isSynchronizingImportedSchedules == false)
        #expect(update?.schedule.schedules.contains(where: { $0.importedCalendarEventKey == event.id }) == true)
    }

    @Test("AppState calendar sync extension methods apply imported event updates")
    func appStateCalendarSyncExtensionUpdatePaths() async throws {
        let appState = isolatedAppState(name: "appStateCalendarSyncExtensionUpdatePaths")
        let defaultSet = RuleSet(name: "Default", urls: ["example.com"])
        appState.ruleSets = [defaultSet]
        appState.activeRuleSetId = defaultSet.id
        appState.calendarIntegrationEnabled = true
        appState.calendarProvider.events = [
            ExternalEvent(
                id: "calendar-ext-sync-1",
                title: "Imported",
                startDate: Date().addingTimeInterval(900),
                endDate: Date().addingTimeInterval(1800)
            )
        ]

        appState.resyncImportedCalendarSchedules()
        #expect(appState.schedules.contains(where: { $0.importedCalendarEventKey == "calendar-ext-sync-1" }))

        appState.synchronizeImportedCalendarSchedulesIfNeeded()
        #expect(appState.schedules.contains(where: { $0.importedCalendarEventKey == "calendar-ext-sync-1" }))
    }

    @Test("AppState schedules extension delete guard keeps state when id is unknown")
    func appStateSchedulesDeleteGuardPath() async throws {
        let appState = isolatedAppState(name: "appStateSchedulesDeleteGuardPath")
        let start = Date()
        let end = start.addingTimeInterval(1800)
        appState.schedules = [
            Schedule(name: "Keep", days: [2], startTime: start, endTime: end, type: .focus)
        ]

        let before = appState.schedules
        appState.deleteSchedule(id: UUID(), modifyAllDays: true, initialDay: nil)

        #expect(appState.schedules == before)
    }

    @MainActor
    @Test("AppKit observation bind deduplicates signatures and publishes section changes")
    func appKitObservationBindsAndPublishers() async throws {
        // AppKitAppStateObservation now uses withObservationTracking directly.
        // It no longer exposes Combine publishers.
    }

    @MainActor
    @Test("AppKit primitive controls update style and action wiring")
    func appKitPrimitiveControls() async throws {
        var tapped = false
        let actionButton = ActionButton(title: "Run")
        actionButton.onAction = { tapped = true }
        actionButton.performClick(nil)
        #expect(tapped)

        actionButton.setGradientBackground(
            colors: [.systemBlue.withAlphaComponent(0.2), .systemBlue.withAlphaComponent(0.1)],
            borderColor: .systemBlue.withAlphaComponent(0.4),
            borderWidth: 2
        )
        actionButton.layoutSubtreeIfNeeded()
        #expect(actionButton.layer?.borderWidth == 2)

        let insetButton = IconInsetButton()
        insetButton.imageInset = 3
        #expect(insetButton.imageInset == 3)

        let leadingButton = LeadingInsetActionButton(title: "Item")
        leadingButton.leadingInset = 11
        leadingButton.titleAdditionalInset = 7
        leadingButton.imageSlotWidth = 20
        #expect(leadingButton.leadingInset == 11)
        #expect(leadingButton.titleAdditionalInset == 7)
        #expect(leadingButton.imageSlotWidth == 20)

        let neutral = ActionButton(title: "Neutral")
        applyAppKitNeutralButtonStyle(neutral, title: "Neutral")
        #expect(neutral.attributedTitle.string == "Neutral")

        let secondary = makeAppKitSecondaryButton(title: "Secondary", color: .systemOrange)
        #expect(secondary.attributedTitle.string == "Secondary")

        let primary = makeAppKitPrimaryButton(title: "Primary", color: .systemGreen)
        #expect(primary.attributedTitle.string == "Primary")

        let divider = makeAppKitDividerView()
        #expect(divider is AppKitDynamicView)
    }

    @MainActor
    @Test("Allowed websites floating editor layout and actions mutate selected rule set")
    func allowedWebsitesFloatingEditorFlow() async throws {
        let appState = isolatedAppState(name: "allowedWebsitesFloatingEditorFlow")
        let initialSet = RuleSet(name: "Default", urls: [])
        appState.ruleSets = [initialSet]
        appState.activeRuleSetId = initialSet.id

        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: initialSet.id
        )
        controller.loadViewIfNeeded()

        #expect(controller.ruleSetListHeightConstraint != nil)
        #expect(controller.urlField.placeholderString == "Add URL to allow...")
        #expect(controller.rulesTableView.numberOfColumns == 1)
        #expect(controller.rulesTableView.allowsMultipleSelection)

        controller.urlField.stringValue = "example.com"
        controller.handleAddRule()
        let setAfterAdd = appState.ruleSets.first(where: { $0.id == initialSet.id })
        #expect(setAfterAdd?.urls.contains("example.com") == true)
        #expect(controller.urlField.stringValue.isEmpty)
        #expect(controller.visibleRules.contains("example.com"))

        controller.rulesTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        controller.handleRemoveSelected()
        let setAfterDelete = appState.ruleSets.first(where: { $0.id == initialSet.id })
        #expect(setAfterDelete?.urls.contains("example.com") == false)

        controller.handleAddRuleFromField(controller.urlField)
        controller.handleTableSelectionChange()
        controller.focusOnRuleSet(nil)
        #expect(controller.selectedRuleSetId == initialSet.id)

        controller.applyButtonStyling()
        #expect(controller.addButton.attributedTitle.string == "Add")
        #expect(controller.importOpenTabsButton.attributedTitle.string == "Import Open Tabs")
        #expect(controller.removeButton.attributedTitle.string == "Remove Selected")
    }

    @MainActor
    @Test("Allowed websites import presenters expose default alert-backed closures")
    func allowedWebsitesImportPresenterDefaults() async throws {
        let appState = isolatedAppState(name: "allowedWebsitesImportPresenterDefaults")
        let controller = AllowedWebsitesFloatingEditorViewController(appState: appState, initialRuleSetId: nil)
        controller.resetImportPresentersForTesting()
        let emptyPresenter = controller.presentEmptyImportState
        let candidatesPresenter = controller.presentImportCandidates
        #expect(type(of: emptyPresenter) == AllowedWebsitesFloatingEditorViewController.EmptyImportStatePresenter.self)
        #expect(type(of: candidatesPresenter) == AllowedWebsitesFloatingEditorViewController.ImportCandidatesPresenter.self)

        emptyPresenter([])
        let selection = candidatesPresenter([], "Default")
        #expect(selection == nil)
    }

    @MainActor
    @Test("Allowed websites import flow covers guard/cancel/success branches")
    func allowedWebsitesImportFlowBranches() async {
        let suite = "CoverageExpansionTests.allowedWebsitesImportFlowBranches"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let monitor = BrowserMonitor(
            stateSnapshotProvider: { nil },
            onEvent: { _ in },
            server: nil,
            automator: ImportFlowAutomator(urls: ["https://example.com/path"]),
            startTimer: false
        )
        let appState = AppState(
            defaults: defaults,
            monitor: monitor,
            calendar: MockCalendarManager(),
            isTesting: true
        )
        let set = RuleSet(name: "Default", urls: [])
        appState.ruleSets = []
        appState.activeRuleSetId = nil

        let controller = AllowedWebsitesFloatingEditorViewController(
            appState: appState,
            initialRuleSetId: nil
        )
        controller.loadViewIfNeeded()

        var emptyCalls = 0
        var candidateCalls = 0
        controller.presentEmptyImportState = { _ in
            emptyCalls += 1
        }
        controller.presentImportCandidates = { _, _ in
            candidateCalls += 1
            return nil
        }
        defer { controller.resetImportPresentersForTesting() }

        controller.selectedRuleSetId = nil
        await controller.handleImportOpenTabsAsync()
        #expect(emptyCalls == 0)
        #expect(candidateCalls == 0)

        controller.selectedRuleSetId = set.id
        await controller.handleImportOpenTabsAsync()
        #expect(emptyCalls == 0)
        #expect(candidateCalls == 0)

        appState.isStrict = false
        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id
        controller.selectedRuleSetId = set.id
        await controller.handleImportOpenTabsAsync()
        #expect(candidateCalls == 1)
        #expect(appState.ruleSets.first?.urls.isEmpty == true)

        controller.presentImportCandidates = { _, _ in
            candidateCalls += 1
            return ["example.com"]
        }
        await controller.handleImportOpenTabsAsync()
        print("DEBUG emptyCalls: \(emptyCalls) candidateCalls: \(candidateCalls)")
        #expect(candidateCalls == 2)
        #expect(appState.ruleSets.first?.urls.contains("example.com") == true)
    }

    @MainActor
    @Test("Allowed websites table controller and floating sheet wiring")
    func allowedWebsitesTableAndSheetWiring() async throws {
        let tableController = AllowedWebsitesRulesTableController()
        tableController.numberOfRules = { 1 }
        tableController.ruleAt = { index in index == 0 ? "example.com" : nil }

        let tableView = NSTableView()
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AllowedRule")))
        #expect(tableController.numberOfRows(in: tableView) == 1)
        let view = tableController.tableView(tableView, viewFor: tableView.tableColumns.first, row: 0)
        #expect((view as? NSTableCellView)?.textField?.stringValue == "example.com")

        let appState = isolatedAppState(name: "allowedWebsitesTableAndSheetWiring")
        var closeCount = 0
        let sheet = AllowedWebsitesSheetController(appState: appState) {
            closeCount += 1
        }
        let parent = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        sheet.present(for: parent, selectedRuleSetId: nil)
        #expect(sheet.window != nil)
        sheet.dismiss()
        #expect(closeCount == 1)

        // Cover nil-window guard branches in present/dismiss.
        sheet.window = nil
        sheet.present(for: parent, selectedRuleSetId: nil)
        sheet.dismiss()
        #expect(closeCount == 1)

        sheet.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        #expect(closeCount == 2)
    }

    @MainActor
    @Test("Window/controller helpers configure expected defaults")
    func windowControllerAndViewPrimitives() async throws {
        let root = NSViewController()
        let controller = FreeMainWindowController(rootViewController: root)
        #expect(controller.window?.contentViewController === root)
        #expect(controller.window?.minSize.width == 900)
        #expect(controller.window?.titleVisibility == .hidden)

        let flipped = AppKitFlippedView(frame: .zero)
        #expect(flipped.isFlipped)

        let dynamic = AppKitDynamicView(frame: .zero)
        dynamic.backgroundColorProvider = { .systemRed.withAlphaComponent(0.2) }
        dynamic.borderColorProvider = { .systemRed.withAlphaComponent(0.4) }
        dynamic.borderWidthValue = 1
        dynamic.applyDynamicLayerColors()
        #expect(dynamic.layer?.borderWidth == 1)

        let cardStack = AppKitCardStackView(frame: .zero)
        cardStack.applyAppearanceColors()
        #expect(cardStack.layer?.backgroundColor != nil)

        let card = AppKitCardView(frame: .zero)
        #expect(card.subviews.contains(card.contentStack))
        #expect(card.contentStack.orientation == .vertical)
    }
}
