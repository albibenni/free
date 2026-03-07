import AppKit
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct FreeAppKitShellTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "FreeAppKitShellTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @Test("VerticalStackScrollContainer uses flipped document coordinates")
    func verticalStackScrollContainerUsesFlippedCoordinates() {
        let scrollView = VerticalStackScrollContainer()

        #expect(scrollView.usesFlippedDocumentCoordinatesForTesting)
    }

    @Test("FreeMainViewController updates sidebar selection for the active section")
    func mainViewControllerUpdatesSidebarSelection() {
        let appState = isolatedAppState(name: "sidebarSelection")
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: true
        )

        controller.loadViewIfNeeded()

        #expect(controller.selectedSectionForTesting == .focus)
        #expect(controller.isSidebarButtonSelectedForTesting(.focus))
        #expect(controller.isSidebarButtonSelectedForTesting(.pomodoro) == false)
        #expect(controller.sidebarButtonLeadingInsetForTesting(.focus) == 6)

        controller.selectSectionForTesting(.pomodoro)

        #expect(controller.selectedSectionForTesting == .pomodoro)
        #expect(controller.isSidebarButtonSelectedForTesting(.focus) == false)
        #expect(controller.isSidebarButtonSelectedForTesting(.pomodoro))

        appState.accentColorIndex = 2
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        let expectedColor = FocusColor.nsColor(for: 2).withAlphaComponent(0.18)
        #expect(controller.selectedSidebarBackgroundColorForTesting == expectedColor)
    }

    @Test("FreeMainViewController keeps the pomodoro controller and widget stable across tab switches")
    func mainViewControllerKeepsPomodoroStableAcrossTabSwitches() {
        let appState = isolatedAppState(name: "pomodoroTabSwitch")
        appState.isTrusted = true
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .pomodoro,
            initialShowSidebar: true
        )

        controller.loadViewIfNeeded()

        let initialPomodoroController = controller.currentContentViewControllerForTesting as? FocusSectionViewController
        let initialPomodoroWidgetIdentifier = controller.pomodoroWidgetIdentifierForTesting

        #expect(initialPomodoroController != nil)
        #expect(initialPomodoroWidgetIdentifier != nil)
        #expect(controller.currentFocusSectionForTesting == .pomodoro)

        controller.selectSectionForTesting(.focus)
        #expect(controller.currentFocusSectionForTesting == .all)

        controller.selectSectionForTesting(.pomodoro)

        #expect(controller.currentFocusSectionForTesting == .pomodoro)
        #expect(controller.currentContentViewControllerForTesting as? FocusSectionViewController === initialPomodoroController)
        #expect(controller.pomodoroWidgetIdentifierForTesting == initialPomodoroWidgetIdentifier)
    }

    @Test("SchedulesSheetViewController manages editor state without SwiftUI hosting")
    func schedulesSheetViewControllerEditorFlow() {
        let controller = SchedulesSheetViewController(
            appState: isolatedAppState(name: "schedulesSheet"),
            onDismiss: {}
        )

        controller.loadViewIfNeeded()

        #expect(controller.viewModeForTesting == 1)
        #expect(controller.editorContextForTesting == nil)

        controller.openAddScheduleForTesting()

        #expect(controller.editorContextForTesting != nil)
    }

    @Test("FreeMainViewController blocks tab switches while floating windows are open")
    func mainViewControllerBlocksTabSwitchesWhenFloatingWindowIsOpen() {
        let appState = isolatedAppState(name: "tabSwitchBlockedByWindow")
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: true
        )

        controller.loadViewIfNeeded()
        #expect(controller.selectedSectionForTesting == .focus)

        controller.setPresentedWindowStatesForTesting(showRules: true, showSchedules: false)
        controller.selectSectionForTesting(.pomodoro)
        #expect(controller.selectedSectionForTesting == .focus)

        controller.setPresentedWindowStatesForTesting(showRules: false, showSchedules: true)
        controller.selectSectionForTesting(.settings)
        #expect(controller.selectedSectionForTesting == .focus)

        controller.setPresentedWindowStatesForTesting(showRules: false, showSchedules: false)
        controller.selectSectionForTesting(.pomodoro)
        #expect(controller.selectedSectionForTesting == .pomodoro)
    }
}
