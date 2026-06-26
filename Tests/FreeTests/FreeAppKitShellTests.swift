import AppKit
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct FreeAppKitShellTests {
    private final class LaunchPromptManager: LaunchAtLoginManaging {
        var isEnabled: Bool = false
        func enable() throws { isEnabled = true }
        func disable() throws { isEnabled = false }
    }

    private func isolatedAppState(name: String) -> AppState {
        let suite = "FreeAppKitShellTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    private func isolatedAppStateWithLaunchPrompt(name: String) -> AppState {
        let suite = "FreeAppKitShellTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let launchManager = LaunchPromptManager()
        return AppState(
            defaults: defaults,
            launchAtLoginManager: launchManager,
            canPromptForLaunchAtLogin: { true },
            isTesting: true
        )
    }

    private func mirrorValue<T>(_ name: String, in root: Any) -> T? {
        var mirror: Mirror? = Mirror(reflecting: root)
        while let current = mirror {
            for child in current.children where child.label == name {
                return child.value as? T
            }
            mirror = current.superclassMirror
        }
        return nil
    }

    @Test("VerticalStackScrollContainer uses flipped document coordinates")
    func verticalStackScrollContainerUsesFlippedCoordinates() async throws {
        let scrollView = VerticalStackScrollContainer()

        #expect(scrollView.usesFlippedDocumentCoordinatesForTesting)
    }

    @Test("FreeMainViewController updates sidebar selection for the active section")
    func mainViewControllerUpdatesSidebarSelection() async throws {
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
        try await Task.sleep(nanoseconds: 100_000_000)
        let expectedColor = FocusColor.nsColor(for: 2).withAlphaComponent(0.18)
        #expect(controller.selectedSidebarBackgroundColorForTesting == expectedColor)
    }

    @Test("FreeMainViewController keeps the pomodoro controller and widget stable across tab switches")
    func mainViewControllerKeepsPomodoroStableAcrossTabSwitches() async throws {
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
    func schedulesSheetViewControllerEditorFlow() async throws {
        let controller = SchedulesSheetViewController(
            appState: isolatedAppState(name: "schedulesSheet"),
            onDismiss: {}
        )

        controller.loadViewIfNeeded()

        #expect(controller.viewModeForTesting == 0)
        #expect(controller.editorContextForTesting == nil)

        controller.openAddScheduleForTesting()

        #expect(controller.editorContextForTesting != nil)
    }

    @Test("FreeMainViewController blocks tab switches only while rules window is open")
    func mainViewControllerBlocksTabSwitchesWhenFloatingWindowIsOpen() async throws {
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
        #expect(controller.selectedSectionForTesting == .settings)

        controller.setPresentedWindowStatesForTesting(showRules: false, showSchedules: false)
        controller.selectSectionForTesting(.pomodoro)
        #expect(controller.selectedSectionForTesting == .pomodoro)
    }

    @Test("FreeMainViewController launch-at-login prompt safely no-ops without a window")
    func mainViewControllerLaunchAtLoginPromptNoWindow() async throws {
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

    @Test("FreeMainViewController launch-at-login prompt presents sheet path when window and prompt eligibility exist")
    func mainViewControllerLaunchAtLoginPromptWithWindow() async throws {
        let appState = isolatedAppStateWithLaunchPrompt(name: "launchPromptWithWindow")
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: true
        )
        controller.loadViewIfNeeded()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        controller.presentLaunchAtLoginPromptIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(controller.selectedSectionForTesting == .focus)
    }

    @Test("FreeMainViewController launch-at-login prompt callback invokes response handler")
    func mainViewControllerLaunchAtLoginPromptCallbackCoverage() async throws {
        defer { FreeMainViewController.resetLaunchAtLoginAlertPresenterForTesting() }

        let appState = isolatedAppStateWithLaunchPrompt(name: "launchPromptCallbackCoverage")
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: true
        )
        controller.loadViewIfNeeded()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        var presented = false
        FreeMainViewController.presentLaunchAtLoginAlert = { _, _, completion in
            presented = true
            completion(.alertFirstButtonReturn)
        }

        controller.presentLaunchAtLoginPromptIfNeeded()
        #expect(presented)
        #expect(appState.launchAtLoginStatus())

        FreeMainViewController.resetLaunchAtLoginAlertPresenterForTesting()
        let smokeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        var completionCalled = false
        FreeMainViewController.presentLaunchAtLoginAlert(NSAlert(), smokeWindow) { _ in
            completionCalled = true
        }
        #expect(completionCalled == false)
    }

    @Test("FreeMainViewController testing hooks cover sidebar callback paths and nil-selection fallback")
    func mainViewControllerTestingHooksCoverage() async throws {
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
    func mainViewControllerLaunchAtLoginResponseHandlerCoverage() async throws {
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
    func mainViewControllerWindowHostedFlowsCoverage() async throws {
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
        try await Task.sleep(nanoseconds: 100_000_000)
        controller.setPresentedWindowStatesForTesting(showRules: false, showSchedules: false)
        try await Task.sleep(nanoseconds: 100_000_000)

        controller.setPresentedWindowStatesForTesting(showRules: false, showSchedules: true)
        try await Task.sleep(nanoseconds: 100_000_000)
        controller.setPresentedWindowStatesForTesting(showRules: false, showSchedules: false)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Cover guarded launch prompt path when window exists.
        controller.presentLaunchAtLoginPromptIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    @Test("FreeMainViewController installs and removes cursor overlay as setting changes")
    func mainViewControllerCursorOverlayVisibilityCoverage() async throws {
        let appState = isolatedAppState(name: "cursorOverlayVisibility")
        appState.cursorFluidAnimationEnabled = true
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: true
        )
        controller.loadViewIfNeeded()

        let initialOverlay: AppKitCursorFluidOverlayView? = mirrorValue(
            "cursorFluidOverlayView",
            in: controller
        )
        #expect(initialOverlay != nil)

        appState.cursorFluidAnimationEnabled = false
        try await Task.sleep(nanoseconds: 100_000_000)
        let removedOverlay: AppKitCursorFluidOverlayView? = mirrorValue(
            "cursorFluidOverlayView",
            in: controller
        )
        #expect(removedOverlay == nil)

        appState.cursorFluidAnimationEnabled = true
        appState.accentColorIndex = FocusColor.rainbowAccentIndex
        try await Task.sleep(nanoseconds: 100_000_000)
        let restoredOverlay: AppKitCursorFluidOverlayView? = mirrorValue(
            "cursorFluidOverlayView",
            in: controller
        )
        #expect(restoredOverlay != nil)
    }

    @Test("FreeMainViewController starts without cursor overlay when animation is disabled")
    func mainViewControllerCursorOverlayDisabledInitialStateCoverage() async throws {
        let appState = isolatedAppState(name: "cursorOverlayDisabledInitial")
        appState.cursorFluidAnimationEnabled = false
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: false
        )
        controller.loadViewIfNeeded()

        let overlay: AppKitCursorFluidOverlayView? = mirrorValue(
            "cursorFluidOverlayView",
            in: controller
        )
        #expect(overlay == nil)

        controller.toggleSidebarForTesting()
        #expect(controller.isSidebarVisibleForTesting)
    }

    @Test("FreeMainViewController disables close button when strict mode is active")
    func mainViewControllerDisablesCloseButtonInStrictMode() async throws {
        let appState = isolatedAppState(name: "closeButtonStrictMode")
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: false
        )
        controller.loadViewIfNeeded()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        #expect(controller.isCloseButtonEnabledForTesting)

        appState.isStrict = true
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(controller.isCloseButtonEnabledForTesting == false)

        appState.isStrict = false
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(controller.isCloseButtonEnabledForTesting)
    }

    @Test("FreeMainViewController handles unavailable cursor overlay factory")
    func mainViewControllerCursorOverlayFactoryNilCoverage() async throws {
        defer { FreeMainViewController.resetLaunchAtLoginAlertPresenterForTesting() }
        FreeMainViewController.setCursorFluidOverlayFactoryForTesting { nil }

        let appState = isolatedAppState(name: "cursorOverlayFactoryNil")
        appState.cursorFluidAnimationEnabled = true
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: true
        )
        controller.loadViewIfNeeded()

        let overlay: AppKitCursorFluidOverlayView? = mirrorValue(
            "cursorFluidOverlayView",
            in: controller
        )
        #expect(overlay == nil)
    }
}
