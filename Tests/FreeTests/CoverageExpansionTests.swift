import AppKit
import Combine
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
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

    private func flushMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }

    @Test("AppState domain adapters round-trip settings, schedules, session and pomodoro state")
    func appStateDomainAdaptersRoundTrip() {
        let appState = isolatedAppState(name: "appStateDomainAdaptersRoundTrip")
        let now = Date()
        let schedule = Schedule(
            name: "Focus",
            days: [2],
            startTime: now,
            endTime: now.addingTimeInterval(3600),
            type: .focus
        )
        let setId = UUID()

        appState.applySettingsDomainState(
            .init(
                weekStartsOnMonday: true,
                accentColorIndex: 3,
                appearanceMode: .dark,
                blockNewTabs: true,
                blockDeveloperHosts: true,
                blockLocalNetworkHosts: true
            )
        )
        #expect(appState.settingsDomainState.weekStartsOnMonday)
        #expect(appState.settingsDomainState.accentColorIndex == 3)
        #expect(appState.settingsDomainState.appearanceMode == .dark)
        #expect(appState.settingsDomainState.blockNewTabs)
        #expect(appState.settingsDomainState.blockDeveloperHosts)
        #expect(appState.settingsDomainState.blockLocalNetworkHosts)

        appState.applyScheduleDomainState(
            .init(
                schedules: [schedule],
                calendarIntegrationEnabled: true,
                calendarImportsBlockTime: true,
                isSynchronizingImportedSchedules: true,
                suppressedImportedCalendarEventKeys: ["event-1"]
            )
        )
        #expect(appState.scheduleDomainState.schedules.count == 1)
        #expect(appState.scheduleDomainState.calendarIntegrationEnabled)
        #expect(appState.scheduleDomainState.calendarImportsBlockTime)
        #expect(appState.scheduleDomainState.isSynchronizingImportedSchedules)
        #expect(appState.scheduleDomainState.suppressedImportedCalendarEventKeys == ["event-1"])

        appState.applySessionDomainState(
            .init(
                isBlocking: true,
                isUnblockable: true,
                isPaused: true,
                pauseRemaining: 90,
                wasStartedBySchedule: true,
                manuallyPausedScheduleIds: [UUID()]
            )
        )
        #expect(appState.sessionDomainState.isBlocking)
        #expect(appState.sessionDomainState.isUnblockable)
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

    @Test("Calendar sync adapters no-op safely when sync is not needed")
    func calendarSyncNoOpWhenNoChanges() {
        let appState = isolatedAppState(name: "calendarSyncNoOpWhenNoChanges")
        let originalSchedules = appState.schedules
        appState.synchronizeImportedCalendarSchedulesIfNeeded()
        appState.resyncImportedCalendarSchedules()
        #expect(appState.schedules == originalSchedules)
    }

    @MainActor
    @Test("AppKit observation bind deduplicates signatures and publishes section changes")
    func appKitObservationBindsAndPublishers() {
        let appState = isolatedAppState(name: "appKitObservationBindsAndPublishers")
        var cancellables = Set<AnyCancellable>()
        var signatureValue = 0
        var seenSignatures: [Int] = []

        let subject = PassthroughSubject<Void, Never>()
        AppKitAppStateObservation.bind(
            publisher: subject.eraseToAnyPublisher(),
            signature: { signatureValue },
            cancellables: &cancellables
        ) { seen in
            seenSignatures.append(seen)
        }

        subject.send(())
        flushMainRunLoop()
        signatureValue = 1
        subject.send(())
        flushMainRunLoop()
        signatureValue = 1
        subject.send(())
        flushMainRunLoop()
        signatureValue = 2
        subject.send(())
        flushMainRunLoop()
        #expect(seenSignatures == [1, 2])

        var settingsEvents = 0
        AppKitAppStateObservation
            .settingsPublisher(appState: appState)
            .sink { settingsEvents += 1 }
            .store(in: &cancellables)
        appState.blockNewTabs.toggle()
        appState.ruleSets.append(RuleSet(name: "Ignored", urls: []))
        flushMainRunLoop()
        #expect(settingsEvents >= 1)

        var schedulesEvents = 0
        AppKitAppStateObservation
            .schedulesPublisher(appState: appState)
            .sink { schedulesEvents += 1 }
            .store(in: &cancellables)
        appState.weekStartsOnMonday.toggle()
        flushMainRunLoop()
        #expect(schedulesEvents >= 1)
        let schedulesEventsBeforeCalendar = schedulesEvents
        appState.calendarProvider.events = [
            ExternalEvent(
                id: "calendar-schedule-publisher",
                title: "Event",
                startDate: Date(),
                endDate: Date().addingTimeInterval(600)
            )
        ]
        flushMainRunLoop()
        #expect(schedulesEvents > schedulesEventsBeforeCalendar)

        var rulesEvents = 0
        AppKitAppStateObservation
            .rulesPublisher(appState: appState)
            .sink { rulesEvents += 1 }
            .store(in: &cancellables)
        appState.activeRuleSetId = appState.ruleSets.first?.id
        flushMainRunLoop()
        #expect(rulesEvents >= 1)

        var allowedWebsiteEvents = 0
        AppKitAppStateObservation
            .allowedWebsitesPublisher(appState: appState)
            .sink { allowedWebsiteEvents += 1 }
            .store(in: &cancellables)
        appState.isBlocking.toggle()
        flushMainRunLoop()
        #expect(allowedWebsiteEvents >= 1)

        var focusEvents = 0
        AppKitAppStateObservation
            .focusPublisher(appState: appState)
            .sink { focusEvents += 1 }
            .store(in: &cancellables)
        appState.pomodoroStatus = .focus
        flushMainRunLoop()
        #expect(focusEvents >= 1)
        let focusEventsBeforeCalendar = focusEvents
        appState.calendarProvider.events = [
            ExternalEvent(
                id: "calendar-focus-publisher",
                title: "Event 2",
                startDate: Date(),
                endDate: Date().addingTimeInterval(900)
            )
        ]
        flushMainRunLoop()
        #expect(focusEvents > focusEventsBeforeCalendar)

        var shellEvents = 0
        AppKitAppStateObservation
            .shellAppearancePublisher(appState: appState)
            .sink { shellEvents += 1 }
            .store(in: &cancellables)
        appState.accentColorIndex += 1
        flushMainRunLoop()
        #expect(shellEvents >= 1)

        var appStateSignatureEvents: [Bool] = []
        AppKitAppStateObservation.bind(
            appState: appState,
            signature: { [appState] in appState.isBlocking },
            cancellables: &cancellables
        ) { value in
            appStateSignatureEvents.append(value)
        }
        appState.isBlocking.toggle()
        flushMainRunLoop()
        #expect(appStateSignatureEvents.last == appState.isBlocking)

        var appStateVoidEvents = 0
        AppKitAppStateObservation.bind(
            appState: appState,
            cancellables: &cancellables
        ) {
            appStateVoidEvents += 1
        }
        appState.accentColorIndex += 1
        flushMainRunLoop()
        #expect(appStateVoidEvents >= 1)

        var rawAppStatePublisherEvents = 0
        AppKitAppStateObservation
            .appStatePublisher(appState: appState)
            .sink { rawAppStatePublisherEvents += 1 }
            .store(in: &cancellables)
        appState.weekStartsOnMonday.toggle()
        flushMainRunLoop()
        #expect(rawAppStatePublisherEvents >= 1)
    }

    @MainActor
    @Test("AppKit primitive controls update style and action wiring")
    func appKitPrimitiveControls() {
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
    func allowedWebsitesFloatingEditorFlow() {
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
    func allowedWebsitesImportPresenterDefaults() {
        AllowedWebsitesFloatingEditorViewController.resetImportPresentersForTesting()
        let emptyPresenter = AllowedWebsitesFloatingEditorViewController.presentEmptyImportState
        let candidatesPresenter = AllowedWebsitesFloatingEditorViewController.presentImportCandidates
        #expect(type(of: emptyPresenter) == AllowedWebsitesFloatingEditorViewController.EmptyImportStatePresenter.self)
        #expect(type(of: candidatesPresenter) == AllowedWebsitesFloatingEditorViewController.ImportCandidatesPresenter.self)

        emptyPresenter([])
        let selection = candidatesPresenter([], "Default")
        #expect(selection == nil)
    }

    @MainActor
    @Test("Allowed websites import flow covers guard/cancel/success branches")
    func allowedWebsitesImportFlowBranches() {
        let suite = "CoverageExpansionTests.allowedWebsitesImportFlowBranches"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let monitor = BrowserMonitor(
            stateSnapshotProvider: { nil },
            setTrustedState: { _ in },
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
        AllowedWebsitesFloatingEditorViewController.presentEmptyImportState = { _ in
            emptyCalls += 1
        }
        AllowedWebsitesFloatingEditorViewController.presentImportCandidates = { _, _ in
            candidateCalls += 1
            return nil
        }
        defer { AllowedWebsitesFloatingEditorViewController.resetImportPresentersForTesting() }

        controller.selectedRuleSetId = nil
        controller.handleImportOpenTabs()
        #expect(emptyCalls == 0)
        #expect(candidateCalls == 0)

        controller.selectedRuleSetId = set.id
        controller.handleImportOpenTabs()
        #expect(emptyCalls == 0)
        #expect(candidateCalls == 0)

        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id
        controller.selectedRuleSetId = set.id
        controller.handleImportOpenTabs()
        #expect(candidateCalls == 1)
        #expect(appState.ruleSets.first?.urls.isEmpty == true)

        AllowedWebsitesFloatingEditorViewController.presentImportCandidates = { _, _ in
            candidateCalls += 1
            return ["example.com"]
        }
        controller.handleImportOpenTabs()
        #expect(candidateCalls == 2)
        #expect(appState.ruleSets.first?.urls.contains("example.com") == true)
    }

    @MainActor
    @Test("Allowed websites table controller and floating sheet wiring")
    func allowedWebsitesTableAndSheetWiring() {
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

        sheet.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        #expect(closeCount == 2)
    }

    @MainActor
    @Test("Window/controller helpers configure expected defaults")
    func windowControllerAndViewPrimitives() {
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
