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

    @Test("FreeMainViewController launch-at-login prompt safely no-ops without a window")
    func mainViewControllerLaunchAtLoginPromptNoWindow() {
        let appState = isolatedAppState(name: "launchPromptNoWindow")
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: true
        )
        controller.loadViewIfNeeded()

        controller.presentLaunchAtLoginPromptIfNeeded()
        #expect(controller.selectedSectionForTesting == .focus)
    }

    @Test("FreeMainViewController testing hooks cover sidebar callback paths and nil-selection fallback")
    func mainViewControllerTestingHooksCoverage() {
        let appState = isolatedAppState(name: "testingHooksCoverage")
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: false
        )

        controller.loadViewIfNeeded()
        #expect(controller.isSidebarVisibleForTesting == false)

        controller.invokeSidebarToggleHandlerForTesting()
        #expect(controller.isSidebarVisibleForTesting)

        controller.invokeSidebarSelectHandlerForTesting(.settings)
        #expect(controller.selectedSectionForTesting == .settings)
    }

    @Test("FreeMainViewController launch-at-login response handler toggles only on enable response")
    func mainViewControllerLaunchAtLoginResponseHandlerCoverage() {
        let appState = isolatedAppState(name: "launchPromptResponseHandler")
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: true
        )
        controller.loadViewIfNeeded()

        let before = appState.launchAtLoginStatus()
        controller.handleLaunchAtLoginPromptResponseForTesting(.alertSecondButtonReturn)
        #expect(appState.launchAtLoginStatus() == before)

        controller.handleLaunchAtLoginPromptResponseForTesting(.alertFirstButtonReturn)
        #expect(appState.launchAtLoginStatus())
    }

    @Test("FreeMainViewController window-hosted flows cover sheet toggles and launch prompt path")
    func mainViewControllerWindowHostedFlowsCoverage() {
        let appState = isolatedAppState(name: "windowHostedFlows")
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: true
        )
        controller.loadViewIfNeeded()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        defer {
            window.orderOut(nil)
        }

        // Cover present + dismiss paths for both rules and schedules sheets.
        controller.setPresentedWindowStatesForTesting(showRules: true, showSchedules: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        controller.setPresentedWindowStatesForTesting(showRules: false, showSchedules: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        controller.setPresentedWindowStatesForTesting(showRules: false, showSchedules: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        controller.setPresentedWindowStatesForTesting(showRules: false, showSchedules: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        // Cover guarded launch prompt path when window exists.
        controller.presentLaunchAtLoginPromptIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
}
