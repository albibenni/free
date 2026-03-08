import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct SectionCoordinatorsTests {
    @Test("Focus interaction coordinator gates deferred and flush reloads")
    func focusInteractionReloadCoordinator() {
        #expect(
            FocusInteractionReloadCoordinator.shouldDeferObservedChange(
                section: .pomodoro,
                interactionDepth: 1
            )
        )
        #expect(
            !FocusInteractionReloadCoordinator.shouldDeferObservedChange(
                section: .all,
                interactionDepth: 1
            )
        )
        #expect(
            FocusInteractionReloadCoordinator.shouldFlushDeferredReload(
                interactionDepth: 0,
                needsReloadAfterInteraction: true
            )
        )
        #expect(
            !FocusInteractionReloadCoordinator.shouldFlushDeferredReload(
                interactionDepth: 1,
                needsReloadAfterInteraction: true
            )
        )
    }

    @Test("Schedules presentation coordinator derives title and week navigation")
    func schedulesSheetPresentationCoordinator() {
        #expect(
            SchedulesSheetPresentationCoordinator.windowTitle(viewMode: 1) == "Schedules · Calendar"
        )
        #expect(
            SchedulesSheetPresentationCoordinator.windowTitle(viewMode: 0) == "Schedules · List"
        )
        #expect(
            SchedulesSheetPresentationCoordinator.weekOffset(
                current: 2,
                action: .previous
            ) == 1
        )
        #expect(
            SchedulesSheetPresentationCoordinator.weekOffset(
                current: 2,
                action: .current
            ) == 0
        )
        #expect(
            SchedulesSheetPresentationCoordinator.weekOffset(
                current: 2,
                action: .next
            ) == 3
        )
    }

    @Test("Focus widget coordinator classifies pomodoro widget reuse actions")
    func focusWidgetCoordinator() {
        let state = AppState(isTesting: true)
        let base = FocusPomodoroWidgetSignature(appState: state)

        #expect(
            FocusSectionWidgetCoordinator.pomodoroReuseAction(
                current: nil,
                next: base
            ) == .refresh
        )

        state.activeRuleSetId = UUID()
        let selectionShift = FocusPomodoroWidgetSignature(appState: state)

        #expect(
            FocusSectionWidgetCoordinator.pomodoroReuseAction(
                current: base,
                next: selectionShift
            ) == .updateSelection
        )

        state.activeRuleSetId = base.activeRuleSetId
        state.pomodoroFocusDuration += 1
        let refreshSig = FocusPomodoroWidgetSignature(appState: state)
        #expect(
            FocusSectionWidgetCoordinator.pomodoroReuseAction(
                current: base,
                next: refreshSig
            ) == .refresh
        )

        #expect(
            FocusSectionWidgetCoordinator.pomodoroReuseAction(
                current: base,
                next: base
            ) == .keepLayout
        )
    }

    @Test("Focus widget factory builds section-specific widget payloads")
    @MainActor
    func focusWidgetFactory() {
        let appState = AppState(isTesting: true)
        let shellState = FreeShellState()

        let pomodoro = FocusSectionWidgetFactory.build(
            section: .pomodoro,
            appState: appState,
            shellState: shellState,
            onPomodoroInteractionDidBegin: {},
            onPomodoroInteractionDidEnd: {}
        )
        #expect(pomodoro.widgetView is FocusPomodoroWidgetView)
        #expect(pomodoro.pomodoroSignature != nil)
        #expect(pomodoro.schedulesSignature == nil)
        #expect(pomodoro.allowedWebsitesSignature == nil)

        let schedules = FocusSectionWidgetFactory.build(
            section: .schedules,
            appState: appState,
            shellState: shellState,
            onPomodoroInteractionDidBegin: {},
            onPomodoroInteractionDidEnd: {}
        )
        #expect(schedules.widgetView is FocusSchedulesWidgetView)
        #expect(schedules.pomodoroSignature == nil)
        #expect(schedules.schedulesSignature != nil)
        #expect(schedules.allowedWebsitesSignature == nil)

        let websites = FocusSectionWidgetFactory.build(
            section: .allowedWebsites,
            appState: appState,
            shellState: shellState,
            onPomodoroInteractionDidBegin: {},
            onPomodoroInteractionDidEnd: {}
        )
        #expect(websites.widgetView is FocusAllowedWebsitesWidgetView)
        #expect(websites.pomodoroSignature == nil)
        #expect(websites.schedulesSignature == nil)
        #expect(websites.allowedWebsitesSignature != nil)

        let all = FocusSectionWidgetFactory.build(
            section: .all,
            appState: appState,
            shellState: shellState,
            onPomodoroInteractionDidBegin: {},
            onPomodoroInteractionDidEnd: {}
        )
        #expect(all.widgetView == nil)
        #expect(all.pomodoroSignature == nil)
        #expect(all.schedulesSignature == nil)
        #expect(all.allowedWebsitesSignature == nil)
    }

    @Test("Focus widget reload coordinator picks reuse, keep, and rebuild operations")
    @MainActor
    func focusWidgetReloadCoordinator() {
        let appState = AppState(isTesting: true)
        let shellState = FreeShellState()

        let initialSignatures = FocusSectionWidgetReloadCoordinator.Signatures(
            pomodoro: FocusPomodoroWidgetSignature(appState: appState),
            schedules: FocusSchedulesWidgetSignature(appState: appState),
            allowedWebsites: FocusAllowedWebsitesWidgetSignature(appState: appState)
        )

        let pomodoroDecision = FocusSectionWidgetReloadCoordinator.decide(
            section: .pomodoro,
            appState: appState,
            shellState: shellState,
            currentWidgetKind: .pomodoro,
            currentSignatures: initialSignatures,
            onPomodoroInteractionDidBegin: {},
            onPomodoroInteractionDidEnd: {}
        )
        switch pomodoroDecision.operation {
        case .reusePomodoro(let action):
            #expect(action == .keepLayout)
        default:
            Issue.record("Expected pomodoro reuse decision")
        }

        let schedulesDecision = FocusSectionWidgetReloadCoordinator.decide(
            section: .schedules,
            appState: appState,
            shellState: shellState,
            currentWidgetKind: .schedules,
            currentSignatures: initialSignatures,
            onPomodoroInteractionDidBegin: {},
            onPomodoroInteractionDidEnd: {}
        )
        switch schedulesDecision.operation {
        case .keepExisting:
            _ = Bool(true)
        default:
            Issue.record("Expected schedules keep-existing decision")
        }

        let allowedDecision = FocusSectionWidgetReloadCoordinator.decide(
            section: .allowedWebsites,
            appState: appState,
            shellState: shellState,
            currentWidgetKind: .none,
            currentSignatures: initialSignatures,
            onPomodoroInteractionDidBegin: {},
            onPomodoroInteractionDidEnd: {}
        )
        switch allowedDecision.operation {
        case .rebuild(let buildResult):
            #expect(buildResult.widgetView is FocusAllowedWebsitesWidgetView)
            #expect(allowedDecision.signatures.allowedWebsites != nil)
        default:
            Issue.record("Expected allowed-websites rebuild decision")
        }
    }

    @Test("Focus widget reload coordinator covers widget-kind fallback and allowed-websites keep-existing path")
    @MainActor
    func focusWidgetReloadCoordinatorAdditionalBranches() {
        let appState = AppState(isTesting: true)
        appState.ruleSets = [RuleSet(name: "Default", urls: ["example.com"])]
        appState.activeRuleSetId = appState.ruleSets.first?.id
        let shellState = FreeShellState()

        #expect(FocusSectionWidgetReloadCoordinator.widgetKind(for: nil) == .none)
        #expect(FocusSectionWidgetReloadCoordinator.widgetKind(for: NSView()) == .other)
        #expect(
            FocusSectionWidgetReloadCoordinator.widgetKind(
                for: FocusAllowedWebsitesWidgetView(appState: appState, shellState: shellState)
            ) == .allowedWebsites
        )

        let signatures = FocusSectionWidgetReloadCoordinator.Signatures(
            pomodoro: nil,
            schedules: FocusSchedulesWidgetSignature(appState: appState),
            allowedWebsites: FocusAllowedWebsitesWidgetSignature(appState: appState)
        )
        let decision = FocusSectionWidgetReloadCoordinator.decide(
            section: .allowedWebsites,
            appState: appState,
            shellState: shellState,
            currentWidgetKind: .allowedWebsites,
            currentSignatures: signatures,
            onPomodoroInteractionDidBegin: {},
            onPomodoroInteractionDidEnd: {}
        )

        switch decision.operation {
        case .keepExisting:
            #expect(decision.signatures.schedules == nil)
            #expect(decision.signatures.allowedWebsites != nil)
        default:
            Issue.record("Expected allowed-websites keep-existing decision")
        }

        let changedAppState = AppState(isTesting: true)
        changedAppState.ruleSets = [RuleSet(name: "Default", urls: ["example.com"])]
        changedAppState.activeRuleSetId = changedAppState.ruleSets.first?.id
        let baseSignatures = FocusSectionWidgetReloadCoordinator.Signatures(
            pomodoro: nil,
            schedules: FocusSchedulesWidgetSignature(appState: changedAppState),
            allowedWebsites: FocusAllowedWebsitesWidgetSignature(appState: changedAppState)
        )

        changedAppState.accentColorIndex += 1
        let schedulesMismatchDecision = FocusSectionWidgetReloadCoordinator.decide(
            section: .schedules,
            appState: changedAppState,
            shellState: shellState,
            currentWidgetKind: .schedules,
            currentSignatures: baseSignatures,
            onPomodoroInteractionDidBegin: {},
            onPomodoroInteractionDidEnd: {}
        )
        switch schedulesMismatchDecision.operation {
        case .rebuild(let build):
            #expect(build.widgetView is FocusSchedulesWidgetView)
        default:
            Issue.record("Expected schedules mismatch to trigger rebuild")
        }

        let allowedBaseSignatures = FocusSectionWidgetReloadCoordinator.Signatures(
            pomodoro: nil,
            schedules: nil,
            allowedWebsites: FocusAllowedWebsitesWidgetSignature(appState: changedAppState)
        )
        changedAppState.ruleSets.append(RuleSet(name: "Extra", urls: []))
        let allowedMismatchDecision = FocusSectionWidgetReloadCoordinator.decide(
            section: .allowedWebsites,
            appState: changedAppState,
            shellState: shellState,
            currentWidgetKind: .allowedWebsites,
            currentSignatures: allowedBaseSignatures,
            onPomodoroInteractionDidBegin: {},
            onPomodoroInteractionDidEnd: {}
        )
        switch allowedMismatchDecision.operation {
        case .rebuild(let build):
            #expect(build.widgetView is FocusAllowedWebsitesWidgetView)
        default:
            Issue.record("Expected allowed-websites mismatch to trigger rebuild")
        }
    }

    @Test("Focus observed-change coordinator routes defer, widget update, and full reload")
    func focusObservedChangeCoordinator() {
        #expect(
            FocusSectionObservedChangeCoordinator.action(
                section: .pomodoro,
                interactionDepth: 1,
                widgetKind: .pomodoro,
                hasPomodoroSignature: true
            ) == .deferReload
        )
        #expect(
            FocusSectionObservedChangeCoordinator.action(
                section: .pomodoro,
                interactionDepth: 0,
                widgetKind: .pomodoro,
                hasPomodoroSignature: true
            ) == .updatePomodoroWidget
        )
        #expect(
            FocusSectionObservedChangeCoordinator.action(
                section: .all,
                interactionDepth: 0,
                widgetKind: .none,
                hasPomodoroSignature: false
            ) == .reloadContent
        )
    }

    @Test("Focus shared-state coordinator computes header status and visibility flags")
    @MainActor
    func focusSharedStateCoordinator() {
        let appState = AppState(isTesting: true)
        appState.isTrusted = false
        appState.isBlocking = true
        appState.isPaused = true
        appState.isUnblockable = true
        appState.pauseRemaining = 75

        let presentation = FocusSectionSharedStateCoordinator.makePresentation(appState: appState)
        #expect(!presentation.isPermissionWarningHidden)
        #expect(presentation.isUnblockableWarningHidden == false)
        #expect(presentation.isPauseDashboardHidden == false)
        #expect(presentation.headerStatusText == "Paused")
        #expect(presentation.pauseTimeText == "01:15")
    }

    @Test("Focus overview render coordinator derives rows and empty-state text")
    @MainActor
    func focusOverviewRenderCoordinator() {
        let defaults = UserDefaults(suiteName: "SectionCoordinatorsTests.focusOverviewRenderCoordinator.\(UUID().uuidString)")!
        let appState = AppState(defaults: defaults, isTesting: true)
        appState.ruleSets = []
        appState.activeRuleSetId = nil
        appState.isBlocking = false
        appState.schedules = []
        appState.pomodoroStatus = .none
        appState.pomodoroRemaining = 0
        let emptyModel = FocusSectionOverviewRenderCoordinator.renderModel(appState: appState)
        #expect(emptyModel.rows.isEmpty)
        #expect(emptyModel.emptyStateText == FocusSectionOverviewRenderCoordinator.emptyStateText)

        let setId = UUID()
        appState.ruleSets = [RuleSet(id: setId, name: "Work", urls: ["example.com"])]
        appState.activeRuleSetId = setId
        appState.isBlocking = true
        let activeModel = FocusSectionOverviewRenderCoordinator.renderModel(appState: appState)
        #expect(!activeModel.rows.isEmpty)
        #expect(activeModel.emptyStateText == nil)
    }

    @Test("Focus overview view applier renders rows or empty message into stack")
    func focusOverviewViewApplier() {
        let stack = NSStackView()
        let rowModel = FocusSectionOverviewRenderCoordinator.RenderModel(
            rows: [
                .init(
                    iconName: AppKitUISymbols.Name.globe,
                    title: "Allow List",
                    value: "Work • 1 rules"
                )
            ],
            emptyStateText: nil
        )

        FocusSectionOverviewViewApplier.apply(
            renderModel: rowModel,
            to: stack,
            accentColorIndex: 0,
            availableWidth: 320
        )
        #expect(stack.arrangedSubviews.count == 1)

        let emptyModel = FocusSectionOverviewRenderCoordinator.RenderModel(
            rows: [],
            emptyStateText: FocusSectionOverviewRenderCoordinator.emptyStateText
        )
        FocusSectionOverviewViewApplier.apply(
            renderModel: emptyModel,
            to: stack,
            accentColorIndex: 0,
            availableWidth: 320
        )
        #expect(stack.arrangedSubviews.count == 1)
        #expect((stack.arrangedSubviews.first as? NSTextField)?.stringValue == FocusSectionOverviewRenderCoordinator.emptyStateText)
    }

    @Test("Focus widget host applier updates container and view hierarchy")
    @MainActor
    func focusWidgetHostApplier() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let current = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        container.addSubview(current)

        FocusSectionWidgetHostApplier.applyKeepExisting(
            isContainerHidden: true,
            widgetContainer: container
        )
        #expect(container.isHidden)

        let next = NSView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        let rebuilt = FocusSectionWidgetHostApplier.applyRebuild(
            buildResult: .init(
                widgetView: next,
                pomodoroSignature: nil,
                schedulesSignature: nil,
                allowedWebsitesSignature: nil
            ),
            currentWidgetView: current,
            widgetContainer: container,
            isContainerHidden: false
        )
        #expect(!container.isHidden)
        #expect(rebuilt === next)
        #expect(container.subviews.count == 1)
        #expect(container.subviews.first === next)

        let appState = AppState(isTesting: true)
        let pomodoroWidget = FocusPomodoroWidgetView(appState: appState)
        container.addSubview(pomodoroWidget)

        FocusSectionWidgetHostApplier.applyPomodoroReuse(
            action: .keepLayout,
            widgetView: pomodoroWidget,
            widgetContainer: container
        )
        #expect(container.isHidden == false)
        #expect(pomodoroWidget.needsLayout)

        appState.ruleSets = [RuleSet(name: "Work", urls: ["example.com"])]
        appState.activeRuleSetId = appState.ruleSets.first?.id
        FocusSectionWidgetHostApplier.applyPomodoroReuse(
            action: .updateSelection,
            widgetView: pomodoroWidget,
            widgetContainer: container
        )
        FocusSectionWidgetHostApplier.applyPomodoroReuse(
            action: .refresh,
            widgetView: pomodoroWidget,
            widgetContainer: container
        )

        let beforeUnknownReuse = container.isHidden
        FocusSectionWidgetHostApplier.applyPomodoroReuse(
            action: .refresh,
            widgetView: NSView(),
            widgetContainer: container
        )
        #expect(container.isHidden == beforeUnknownReuse)

        let noWidget = FocusSectionWidgetHostApplier.applyRebuild(
            buildResult: .init(
                widgetView: nil,
                pomodoroSignature: nil,
                schedulesSignature: nil,
                allowedWebsitesSignature: nil
            ),
            currentWidgetView: next,
            widgetContainer: container,
            isContainerHidden: true
        )
        #expect(noWidget == nil)
        #expect(container.isHidden)
    }

    @Test("Focus visibility coordinator maps section to overview and widget visibility")
    func focusVisibilityCoordinator() {
        let all = FocusSectionVisibilityCoordinator.visibility(for: .all)
        #expect(all.shouldShowOverview)
        #expect(all.isWidgetContainerHidden)

        let pomodoro = FocusSectionVisibilityCoordinator.visibility(for: .pomodoro)
        #expect(!pomodoro.shouldShowOverview)
        #expect(!pomodoro.isWidgetContainerHidden)

        let schedules = FocusSectionVisibilityCoordinator.visibility(for: .schedules)
        #expect(!schedules.shouldShowOverview)
        #expect(!schedules.isWidgetContainerHidden)
    }
}
