import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct FocusViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "FocusViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host(
        _ controller: NSViewController,
        size: CGSize = CGSize(width: 980, height: 980)
    ) -> NSView {
        controller.loadViewIfNeeded()
        controller.view.frame = NSRect(origin: .zero, size: size)
        controller.view.layoutSubtreeIfNeeded()
        controller.view.displayIfNeeded()
        return controller.view
    }

    @MainActor
    private func makeController(
        appState: AppState,
        section: FocusContentSection
    ) -> FocusSectionViewController {
        FocusSectionViewController(
            appState: appState,
            shellState: FreeShellState(),
            section: section
        )
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

        for subview in view.subviews {
            values.append(contentsOf: visibleText(in: subview))
        }
        return values
    }

    private func buttons(in view: NSView) -> [NSButton] {
        var all: [NSButton] = []
        if let button = view as? NSButton {
            all.append(button)
        }
        for subview in view.subviews {
            all.append(contentsOf: buttons(in: subview))
        }
        return all
    }

    @Test("Focus section support covers warning/icon/status/pause/action paths")
    func focusViewHelperLogic() {
        #expect(FocusSectionSupport.shouldShowUnblockableWarning(isBlocking: true, isUnblockable: true))
        #expect(!FocusSectionSupport.shouldShowUnblockableWarning(isBlocking: false, isUnblockable: true))
        #expect(!FocusSectionSupport.shouldShowUnblockableWarning(isBlocking: true, isUnblockable: false))

        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = FocusSectionSupport.accessibilityPromptOptions() as NSDictionary
        #expect((options[key] as? Bool) == true)

        var grantCallCount = 0
        var capturedOptions: NSDictionary?
        let grantAction = FocusSectionSupport.makeGrantAccessibilityAction { options in
            grantCallCount += 1
            capturedOptions = options as NSDictionary
            return true
        }
        grantAction()
        #expect(grantCallCount == 1)
        #expect((capturedOptions?[key] as? Bool) == true)

        #expect(FocusSectionSupport.focusIconColor(isBlocking: true, isPaused: false) == .systemGreen)
        #expect(FocusSectionSupport.focusIconColor(isBlocking: true, isPaused: true) == .systemGray)
        #expect(FocusSectionSupport.focusIconColor(isBlocking: false, isPaused: false) == .systemGray)

        #expect(FocusSectionSupport.statusLabel(isBlocking: false, isPaused: false) == "Inactive")
        #expect(FocusSectionSupport.statusLabel(isBlocking: true, isPaused: false) == "Active")
        #expect(FocusSectionSupport.statusLabel(isBlocking: true, isPaused: true) == "Paused")

        #expect(FocusSectionSupport.shouldShowRuleSetName(isBlocking: true, isPaused: false))
        #expect(!FocusSectionSupport.shouldShowRuleSetName(isBlocking: true, isPaused: true))
        #expect(!FocusSectionSupport.shouldShowRuleSetName(isBlocking: false, isPaused: false))

        #expect(FocusSectionSupport.shouldShowPauseDashboard(isBlocking: true, isPaused: true))
        #expect(!FocusSectionSupport.shouldShowPauseDashboard(isBlocking: true, isPaused: false))
        #expect(!FocusSectionSupport.shouldShowPauseDashboard(isBlocking: false, isPaused: true))

        #expect(
            FocusSectionSupport.shouldShowAllowListPreview(
                isBlocking: true,
                pomodoroStatus: .none,
                hasActiveFocusSchedule: false,
                hasCurrentRuleSet: true
            )
        )
        #expect(
            FocusSectionSupport.shouldShowAllowListPreview(
                isBlocking: false,
                pomodoroStatus: .focus,
                hasActiveFocusSchedule: false,
                hasCurrentRuleSet: true
            )
        )
        #expect(
            FocusSectionSupport.shouldShowAllowListPreview(
                isBlocking: false,
                pomodoroStatus: .none,
                hasActiveFocusSchedule: true,
                hasCurrentRuleSet: true
            )
        )
        #expect(
            !FocusSectionSupport.shouldShowAllowListPreview(
                isBlocking: false,
                pomodoroStatus: .none,
                hasActiveFocusSchedule: false,
                hasCurrentRuleSet: true
            )
        )
        #expect(
            !FocusSectionSupport.shouldShowAllowListPreview(
                isBlocking: true,
                pomodoroStatus: .focus,
                hasActiveFocusSchedule: true,
                hasCurrentRuleSet: false
            )
        )

        #expect(FocusSectionSupport.pomodoroPhaseLabel(status: .none) == "Inactive")
        #expect(FocusSectionSupport.pomodoroPhaseLabel(status: .focus) == "Focus")
        #expect(FocusSectionSupport.pomodoroPhaseLabel(status: .breakTime) == "Break")

        let appState = isolatedAppState(name: "cancelPauseAction")
        appState.isPaused = true
        let cancelPause = FocusSectionSupport.makeCancelPauseAction(cancelPause: { appState.cancelPause() })
        cancelPause()
        #expect(appState.isPaused == false)
    }

    @Test("Focus section grant accessibility action delegates through controller factory")
    @MainActor
    func focusGrantAccessibilityAction() {
        let appState = isolatedAppState(name: "grantAccessibility")
        let controller = makeController(appState: appState, section: .all)
        _ = host(controller)

        var didInvoke = false
        controller.grantAccessibilityActionFactory = {
            { didInvoke = true }
        }

        controller.grantAccessibility()
        #expect(didInvoke)
    }

    @Test("Focus section cancelPause action clears pause state and keeps reload flags consistent")
    @MainActor
    func focusCancelPauseAction() {
        let appState = isolatedAppState(name: "cancelPauseControllerAction")
        appState.isBlocking = true
        appState.isPaused = true
        appState.pauseRemaining = 120

        let controller = makeController(appState: appState, section: .all)
        _ = host(controller)

        controller.needsReloadAfterPomodoroInteraction = true
        controller.cancelPause()

        #expect(appState.isPaused == false)
        #expect(controller.hasDeferredPomodoroReloadForTesting == false)
    }

    @Test("Focus section end interaction guard does not flush when depth is zero")
    @MainActor
    func focusEndInteractionGuardAtZeroDepth() {
        let appState = isolatedAppState(name: "endInteractionGuard")
        let controller = makeController(appState: appState, section: .pomodoro)
        _ = host(controller)

        controller.needsReloadAfterPomodoroInteraction = true
        controller.endPomodoroWidgetInteractionForTesting()

        #expect(controller.hasDeferredPomodoroReloadForTesting)

        controller.beginPomodoroWidgetInteractionForTesting()
        controller.endPomodoroWidgetInteractionForTesting()

        #expect(controller.hasDeferredPomodoroReloadForTesting == false)
    }

    @Test("Focus section shows live overview instead of full widgets")
    @MainActor
    func focusViewLiveOverviewRender() {
        let appState = isolatedAppState(name: "liveOverview")
        appState.isBlocking = true
        appState.ruleSets = [RuleSet(name: "Work", urls: ["example.com", "developer.apple.com"])]
        appState.activeRuleSetId = appState.ruleSets.first?.id

        let controller = makeController(appState: appState, section: .all)
        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(texts.contains("Live Overview"))
        #expect(texts.contains("Allow List"))
        #expect(texts.contains("Pomodoro Mode") == false)
        #expect(texts.contains("Focus Schedules") == false)
        #expect(texts.contains("Allowed Websites") == false)
    }

    @Test("Focus section live overview renders active schedules and pomodoro previews")
    @MainActor
    func focusViewLiveOverviewActivePreviews() {
        let appState = isolatedAppState(name: "liveOverviewActivePreviews")
        appState.isBlocking = true
        let rules = RuleSet(name: "Work", urls: ["example.com"])
        appState.ruleSets = [rules]
        appState.activeRuleSetId = rules.id
        appState.pomodoroStatus = .focus
        appState.pomodoroRemaining = 900

        let now = Date()
        let today = Calendar.current.component(.weekday, from: now)
        appState.schedules = [
            Schedule(
                name: "Deep Work",
                days: [today],
                startTime: now.addingTimeInterval(-1800),
                endTime: now.addingTimeInterval(1800),
                isEnabled: true,
                type: .focus
            )
        ]

        let controller = makeController(appState: appState, section: .all)
        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(texts.contains("Active Schedules"))
        #expect(texts.contains("Pomodoro"))
        #expect(texts.contains("No active schedule, allow list, or pomodoro session.") == false)
    }

    @Test("Focus section pomodoro mode renders AppKit widget without overview")
    @MainActor
    func focusViewPomodoroSectionRender() {
        let appState = isolatedAppState(name: "pomodoroSection")
        appState.isTrusted = true

        let controller = makeController(appState: appState, section: .pomodoro)
        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(controller.currentWidgetViewTypeForTesting == "FocusPomodoroWidgetView")
        #expect(texts.contains("Pomodoro Mode"))
        #expect(texts.contains("Live Overview") == false)
    }

    @Test("Focus section defers pomodoro widget rebuild while a dial drag is active")
    @MainActor
    func focusViewDefersPomodoroWidgetReloadDuringDialInteraction() {
        let appState = isolatedAppState(name: "pomodoroDialInteraction")
        let controller = makeController(appState: appState, section: .pomodoro)

        _ = host(controller)
        let initialWidgetIdentifier = controller.widgetViewIdentifierForTesting
        let initialRefreshGeneration = controller.pomodoroWidgetRefreshGenerationForTesting

        #expect(initialWidgetIdentifier != nil)
        #expect(initialRefreshGeneration != nil)

        controller.beginPomodoroWidgetInteractionForTesting()
        appState.pomodoroFocusDuration = 50
        controller.simulateObservedAppStateChangeForTesting()

        #expect(controller.widgetViewIdentifierForTesting == initialWidgetIdentifier)
        #expect(controller.hasDeferredPomodoroReloadForTesting)
        #expect(controller.pomodoroWidgetRefreshGenerationForTesting == initialRefreshGeneration)

        controller.endPomodoroWidgetInteractionForTesting()

        #expect(controller.hasDeferredPomodoroReloadForTesting == false)
        #expect(controller.widgetViewIdentifierForTesting != nil)
        #expect(controller.widgetViewIdentifierForTesting == initialWidgetIdentifier)
        #expect(controller.pomodoroWidgetRefreshGenerationForTesting == initialRefreshGeneration)
    }

    @Test("Focus section widget interaction callbacks execute through reloadWidget closure wiring")
    @MainActor
    func focusViewPomodoroWidgetInteractionCallbackWiring() {
        let appState = isolatedAppState(name: "pomodoroInteractionCallbackWiring")
        let controller = makeController(appState: appState, section: .pomodoro)

        _ = host(controller)
        #expect(controller.currentWidgetViewTypeForTesting == "FocusPomodoroWidgetView")
        #expect(controller.hasDeferredPomodoroReloadForTesting == false)

        controller.needsReloadAfterPomodoroInteraction = true
        let callbackState = controller.simulatePomodoroWidgetInteractionCallbacksForTesting()

        #expect(callbackState?.didBegin == true)
        #expect(callbackState?.didEnd == true)
        #expect(controller.hasDeferredPomodoroReloadForTesting == false)
    }

    @Test("Focus section keeps pomodoro widget instance when unrelated app state changes")
    @MainActor
    func focusViewKeepsPomodoroWidgetForUnrelatedStateChanges() {
        let appState = isolatedAppState(name: "pomodoroUnrelatedStateChange")
        appState.isTrusted = true
        let controller = makeController(appState: appState, section: .pomodoro)

        _ = host(controller)
        let initialWidgetIdentifier = controller.widgetViewIdentifierForTesting
        let initialRefreshGeneration = controller.pomodoroWidgetRefreshGenerationForTesting

        #expect(initialWidgetIdentifier != nil)
        #expect(initialRefreshGeneration != nil)

        appState.currentOpenUrls = ["https://example.com"]
        controller.simulateObservedAppStateChangeForTesting()

        #expect(controller.widgetViewIdentifierForTesting == initialWidgetIdentifier)
        #expect(controller.pomodoroWidgetRefreshGenerationForTesting == initialRefreshGeneration)
    }

    @Test("Focus section keeps pomodoro widget instance when switching selected list")
    @MainActor
    func focusViewKeepsPomodoroWidgetForListSelectionChanges() {
        let appState = isolatedAppState(name: "pomodoroListSelectionChange")
        appState.isTrusted = true
        appState.isBlocking = true
        appState.ruleSets = [
            RuleSet(name: "Default", urls: ["example.com"]),
            RuleSet(name: "test", urls: ["example.org"]),
        ]
        appState.activeRuleSetId = appState.ruleSets.first?.id

        let controller = makeController(appState: appState, section: .pomodoro)
        _ = host(controller)

        let initialWidgetIdentifier = controller.widgetViewIdentifierForTesting
        let initialRefreshGeneration = controller.pomodoroWidgetRefreshGenerationForTesting
        let initialHeaderStatus = controller.headerStatusTextForTesting

        #expect(initialWidgetIdentifier != nil)
        #expect(initialRefreshGeneration != nil)
        #expect(initialHeaderStatus.contains("Default"))

        appState.activeRuleSetId = appState.ruleSets.last?.id
        controller.simulateObservedAppStateChangeForTesting()

        #expect(controller.widgetViewIdentifierForTesting == initialWidgetIdentifier)
        #expect(controller.pomodoroWidgetRefreshGenerationForTesting == initialRefreshGeneration)
        #expect(controller.headerStatusTextForTesting.contains("test"))
    }

    @Test("Focus layout builder overview row clamps width to minimum when available width is non-positive")
    @MainActor
    func focusLayoutBuilderOverviewRowWidthClamp() {
        let clamped = FocusSectionLayoutBuilder.makeOverviewRow(
            iconName: AppKitUISymbols.Name.focus,
            title: "Title",
            value: "Value",
            accentColorIndex: 0,
            availableWidth: 0
        )
        let widthConstraint = clamped.constraints.first(where: {
            $0.firstAttribute == .width && $0.relation == .equal
        })
        #expect(widthConstraint?.constant == 1)

        let regular = FocusSectionLayoutBuilder.makeOverviewRow(
            iconName: AppKitUISymbols.Name.focus,
            title: "Title",
            value: "Value",
            accentColorIndex: 0,
            availableWidth: 220
        )
        let regularWidthConstraint = regular.constraints.first(where: {
            $0.firstAttribute == .width && $0.relation == .equal
        })
        #expect(regularWidthConstraint?.constant == 220)

        let fallbackIconRow = FocusSectionLayoutBuilder.makeOverviewRow(
            iconName: "definitely.not.a.symbol",
            title: "Fallback",
            value: "Value",
            accentColorIndex: 1,
            availableWidth: 160
        )
        #expect(fallbackIconRow.subviews.isEmpty == false)
    }

    @Test("Focus section keeps pomodoro widget stable when applying a preset")
    @MainActor
    func focusViewKeepsPomodoroWidgetForPresetChanges() {
        let appState = isolatedAppState(name: "pomodoroPresetChange")
        appState.isTrusted = true
        let controller = makeController(appState: appState, section: .pomodoro)
        let hosted = host(controller)

        let initialWidgetIdentifier = controller.widgetViewIdentifierForTesting
        let initialRefreshGeneration = controller.pomodoroWidgetRefreshGenerationForTesting

        #expect(initialWidgetIdentifier != nil)
        #expect(initialRefreshGeneration != nil)

        let presetButton = buttons(in: hosted).first { $0.title == "45/15" }
        #expect(presetButton != nil)

        presetButton?.performClick(nil)

        #expect(appState.pomodoroFocusDuration == 45)
        #expect(appState.pomodoroBreakDuration == 15)
        #expect(controller.widgetViewIdentifierForTesting == initialWidgetIdentifier)
        #expect(controller.pomodoroWidgetRefreshGenerationForTesting == initialRefreshGeneration)
    }

    @Test("Focus section keeps pomodoro widget stable when starting a pomodoro")
    @MainActor
    func focusViewKeepsPomodoroWidgetForStartTransition() {
        let appState = isolatedAppState(name: "pomodoroStartTransition")
        appState.isTrusted = true
        let controller = makeController(appState: appState, section: .pomodoro)
        let hosted = host(controller)

        let initialWidgetIdentifier = controller.widgetViewIdentifierForTesting
        let initialRefreshGeneration = controller.pomodoroWidgetRefreshGenerationForTesting

        #expect(initialWidgetIdentifier != nil)
        #expect(initialRefreshGeneration != nil)

        let startButton = buttons(in: hosted).first { $0.title == "Start Focus Session" }
        #expect(startButton != nil)

        startButton?.performClick(nil)

        #expect(appState.pomodoroStatus == .focus)
        #expect(controller.widgetViewIdentifierForTesting == initialWidgetIdentifier)
        #expect(controller.pomodoroWidgetRefreshGenerationForTesting == initialRefreshGeneration)
    }

    @Test("Focus section switching preserves widget reuse behavior when returning to pomodoro")
    @MainActor
    func focusViewSectionSwitchingKeepsPomodoroReuse() {
        let appState = isolatedAppState(name: "sectionSwitchingPomodoroReuse")
        appState.isTrusted = true
        appState.isBlocking = true
        appState.ruleSets = [
            RuleSet(name: "Default", urls: ["example.com"]),
            RuleSet(name: "Study", urls: ["example.org"]),
        ]
        appState.activeRuleSetId = appState.ruleSets.first?.id
        appState.schedules = [
            Schedule(
                name: "Study Block",
                days: [Calendar.current.component(.weekday, from: Date())],
                startTime: Date().addingTimeInterval(-300),
                endTime: Date().addingTimeInterval(1200),
                colorIndex: 1,
                type: .focus
            )
        ]

        let controller = makeController(appState: appState, section: .pomodoro)
        _ = host(controller)

        let initialPomodoroId = controller.widgetViewIdentifierForTesting
        #expect(controller.currentWidgetViewTypeForTesting == "FocusPomodoroWidgetView")
        #expect(initialPomodoroId != nil)

        controller.section = .schedules
        controller.view.layoutSubtreeIfNeeded()
        #expect(controller.currentWidgetViewTypeForTesting == "FocusSchedulesWidgetView")

        controller.section = .pomodoro
        controller.view.layoutSubtreeIfNeeded()
        let returnedPomodoroId = controller.widgetViewIdentifierForTesting
        let returnedRefreshGeneration = controller.pomodoroWidgetRefreshGenerationForTesting
        #expect(controller.currentWidgetViewTypeForTesting == "FocusPomodoroWidgetView")
        #expect(returnedPomodoroId != nil)
        #expect(returnedPomodoroId != initialPomodoroId)
        #expect(returnedRefreshGeneration != nil)

        appState.activeRuleSetId = appState.ruleSets.last?.id
        controller.simulateObservedAppStateChangeForTesting()
        #expect(controller.widgetViewIdentifierForTesting == returnedPomodoroId)
        #expect(controller.pomodoroWidgetRefreshGenerationForTesting == returnedRefreshGeneration)
    }

    @Test("Focus section schedules widget stays mounted for unrelated app-state changes")
    @MainActor
    func focusViewKeepsSchedulesWidgetForUnrelatedStateChanges() {
        let appState = isolatedAppState(name: "schedulesUnrelatedStateChange")
        appState.isTrusted = true
        appState.schedules = [
            Schedule(
                name: "Study",
                days: [Calendar.current.component(.weekday, from: Date())],
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                colorIndex: 1,
                type: .focus
            )
        ]

        let controller = makeController(appState: appState, section: .schedules)
        _ = host(controller)
        let initialWidgetIdentifier = controller.widgetViewIdentifierForTesting

        #expect(initialWidgetIdentifier != nil)

        appState.currentOpenUrls = ["https://example.com"]
        controller.simulateObservedAppStateChangeForTesting()

        #expect(controller.widgetViewIdentifierForTesting == initialWidgetIdentifier)
    }

    @Test("Focus section allowed-websites mode renders AppKit widget without overview")
    @MainActor
    func focusViewAllowedWebsitesSectionRender() {
        let appState = isolatedAppState(name: "allowedWebsitesSection")
        appState.isTrusted = true
        appState.ruleSets = [RuleSet(name: "Default", urls: ["example.com"])]
        appState.activeRuleSetId = appState.ruleSets.first?.id

        let controller = makeController(appState: appState, section: .allowedWebsites)
        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(controller.currentWidgetViewTypeForTesting == "FocusAllowedWebsitesWidgetView")
        #expect(texts.contains("Allowed Websites"))
        #expect(texts.contains("Live Overview") == false)
    }

    @Test("Focus section live overview handles missing rule-set context")
    @MainActor
    func focusViewLiveOverviewMissingRuleSetContext() {
        let appState = isolatedAppState(name: "missingRuleSetContext")
        appState.ruleSets = []
        appState.activeRuleSetId = nil
        appState.isBlocking = false
        appState.pomodoroStatus = .none

        let controller = makeController(appState: appState, section: .all)
        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(texts.contains("Allow List") == false)
        #expect(texts.contains("No active schedule, allow list, or pomodoro session."))
    }

    @Test("Focus section renders trusted inactive state")
    @MainActor
    func focusViewRenderTrustedInactive() {
        let appState = isolatedAppState(name: "trustedInactive")
        appState.isTrusted = true
        appState.isBlocking = false
        appState.isPaused = false
        appState.isUnblockable = false

        let controller = makeController(appState: appState, section: .all)
        let hosted = host(controller)

        #expect(hosted.fittingSize.width >= 0)
        #expect(controller.isPermissionWarningHiddenForTesting)
        #expect(controller.headerStatusTextForTesting == "Inactive")
    }

    @Test("Focus section renders blocking active unblockable state with list name")
    @MainActor
    func focusViewRenderBlockingActiveUnblockable() {
        let appState = isolatedAppState(name: "activeUnblockable")
        appState.isTrusted = false
        appState.isBlocking = true
        appState.isPaused = false
        appState.isUnblockable = true
        let rules = RuleSet(name: "Work List", urls: ["example.com"])
        appState.ruleSets = [rules]
        appState.activeRuleSetId = rules.id

        let controller = makeController(appState: appState, section: .all)
        _ = host(controller)

        #expect(controller.isPermissionWarningHiddenForTesting == false)
        #expect(controller.isUnblockableWarningHiddenForTesting == false)
        #expect(controller.headerStatusTextForTesting == "Active • Work List")
    }

    @Test("Focus section renders paused dashboard state")
    @MainActor
    func focusViewRenderPausedDashboard() {
        let appState = isolatedAppState(name: "pausedDashboard")
        appState.isTrusted = false
        appState.isBlocking = true
        appState.isPaused = true
        appState.pauseRemaining = 125

        let controller = makeController(appState: appState, section: .all)
        let hosted = host(controller)

        #expect(hosted.fittingSize.width >= 0)
        #expect(controller.isPauseDashboardHiddenForTesting == false)
        #expect(controller.pauseTimeTextForTesting == "02:05")
    }

    @Test("End Break & Focus button cancels pause from pomodoro section")
    @MainActor
    func focusViewPauseEndButtonCancelsPause() {
        let appState = isolatedAppState(name: "pauseEndButton")
        appState.isTrusted = true
        appState.isBlocking = true
        appState.isPaused = true
        appState.pauseRemaining = 180

        let controller = makeController(appState: appState, section: .pomodoro)
        let hosted = host(controller)
        let endButton = buttons(in: hosted).first { $0.title == "End Break & Focus" }

        #expect(endButton != nil)
        endButton?.performClick(nil)

        #expect(appState.isPaused == false)
        #expect(controller.isPauseDashboardHiddenForTesting == true)
    }

    @Test("End Break & Focus button works after starting quick break in pomodoro section")
    @MainActor
    func focusViewPauseEndButtonAfterQuickBreakStart() {
        let appState = isolatedAppState(name: "pauseEndAfterQuickBreak")
        appState.isTrusted = true
        appState.isBlocking = true

        let controller = makeController(appState: appState, section: .pomodoro)
        let hosted = host(controller)

        appState.startPause(minutes: 5)
        controller.simulateObservedAppStateChangeForTesting()
        hosted.layoutSubtreeIfNeeded()

        #expect(controller.isPauseDashboardHiddenForTesting == false)
        let endButton = buttons(in: hosted).first { $0.title == "End Break & Focus" }
        #expect(endButton != nil)

        endButton?.performClick(nil)
        #expect(appState.isPaused == false)
        #expect(controller.isPauseDashboardHiddenForTesting == true)
    }

    @Test("Focus schedules widget reload keeps existing view when signature is unchanged")
    @MainActor
    func focusSchedulesWidgetKeepExistingReload() {
        let appState = isolatedAppState(name: "schedulesKeepExistingReload")
        let now = Date()
        let weekday = Calendar.current.component(.weekday, from: now)
        appState.schedules = [
            Schedule(
                name: "Deep Work",
                days: [weekday],
                startTime: now.addingTimeInterval(-1800),
                endTime: now.addingTimeInterval(1800),
                isEnabled: true,
                type: .focus
            )
        ]

        let controller = makeController(appState: appState, section: .schedules)
        _ = host(controller)
        let initialIdentifier = controller.widgetViewIdentifierForTesting
        #expect(controller.currentWidgetViewTypeForTesting == "FocusSchedulesWidgetView")

        controller.reloadWidget()

        #expect(controller.currentWidgetViewTypeForTesting == "FocusSchedulesWidgetView")
        #expect(controller.widgetViewIdentifierForTesting == initialIdentifier)
    }

    @Test("Focus allowed websites widget reload keeps existing view when signature is unchanged")
    @MainActor
    func focusAllowedWebsitesWidgetKeepExistingReload() {
        let appState = isolatedAppState(name: "allowedWebsitesKeepExistingReload")
        let set = RuleSet(name: "Default", urls: ["swift.org"])
        appState.ruleSets = [set]
        appState.activeRuleSetId = set.id

        let controller = makeController(appState: appState, section: .allowedWebsites)
        _ = host(controller)
        let initialIdentifier = controller.widgetViewIdentifierForTesting
        #expect(controller.currentWidgetViewTypeForTesting == "FocusAllowedWebsitesWidgetView")

        controller.reloadWidget()

        #expect(controller.currentWidgetViewTypeForTesting == "FocusAllowedWebsitesWidgetView")
        #expect(controller.widgetViewIdentifierForTesting == initialIdentifier)
    }
}
