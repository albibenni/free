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
        let cancelPause = FocusSectionSupport.makeCancelPauseAction(appState: appState)
        cancelPause()
        #expect(appState.isPaused == false)
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
}
