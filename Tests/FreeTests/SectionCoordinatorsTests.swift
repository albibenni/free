import Foundation
import Testing

@testable import FreeLogic

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
        let state = AppState()
        let base = FocusPomodoroWidgetSignature(appState: state)

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
        let appState = AppState()
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
}
