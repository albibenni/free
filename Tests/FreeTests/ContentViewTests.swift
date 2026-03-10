import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct ContentViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "ContentViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host(
        _ controller: NSViewController,
        size: CGSize = CGSize(width: 960, height: 820)
    ) -> NSView {
        controller.loadViewIfNeeded()
        controller.view.frame = NSRect(origin: .zero, size: size)
        controller.view.layoutSubtreeIfNeeded()
        controller.view.displayIfNeeded()
        return controller.view
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

    @Test("Main shell controller covers sidebar state and section switching")
    @MainActor
    func mainShellControllerState() {
        let controller = FreeMainViewController(
            appState: isolatedAppState(name: "mainShellState"),
            initialSection: .focus,
            initialShowSidebar: false
        )

        _ = host(controller)

        #expect(controller.isSidebarVisibleForTesting == false)
        #expect(controller.selectedSectionForTesting == .focus)
        #expect(controller.currentFocusSectionForTesting == .all)

        controller.toggleSidebarForTesting()
        #expect(controller.isSidebarVisibleForTesting)

        controller.selectSectionForTesting(.pomodoro)
        #expect(controller.selectedSectionForTesting == .pomodoro)
        #expect(controller.currentFocusSectionForTesting == .pomodoro)
        #expect(controller.isSidebarButtonSelectedForTesting(.pomodoro))
        #expect(controller.isSidebarButtonSelectedForTesting(.focus) == false)

        controller.selectSectionForTesting(.settings)
        #expect(controller.selectedSectionForTesting == .settings)
        #expect(controller.currentContentViewControllerForTesting is SettingsSectionViewController)
    }

    @Test("Main shell renders expanded sidebar menu with section entries and settings")
    @MainActor
    func mainShellExpandedSidebarRender() {
        let controller = FreeMainViewController(
            appState: isolatedAppState(name: "expandedSidebar"),
            initialShowSidebar: true
        )

        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(texts.contains("Menu"))
        #expect(texts.contains("Focus"))
        #expect(texts.contains("Schedules"))
        #expect(texts.contains("Calendar"))
        #expect(texts.contains("Allowed Websites"))
        #expect(texts.contains("Pomodoro"))
        #expect(texts.contains("Settings"))
    }

    @Test("Main shell schedules section loads AppKit schedules widget")
    @MainActor
    func mainShellSchedulesSectionOpensWidget() {
        let appState = isolatedAppState(name: "schedulesSection")
        appState.schedules = [
            Schedule(
                name: "Morning Focus",
                days: [Calendar.current.component(.weekday, from: Date())],
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                isEnabled: true,
                type: .focus
            )
        ]

        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .schedules,
            initialShowSidebar: true
        )

        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(controller.currentFocusSectionForTesting == .schedules)
        let focusController = controller.currentContentViewControllerForTesting as? FocusSectionViewController
        #expect(focusController?.currentWidgetViewTypeForTesting == "FocusSchedulesWidgetView")
        #expect(texts.contains("Focus Schedules"))
        #expect(texts.contains("Open Full Calendar"))
    }

    @Test("Main shell settings section renders AppKit settings controller")
    @MainActor
    func mainShellSettingsSectionRender() {
        let controller = FreeMainViewController(
            appState: isolatedAppState(name: "settingsSection"),
            initialSection: .settings,
            initialShowSidebar: true
        )

        let hosted = host(controller)
        let texts = visibleText(in: hosted)

        #expect(controller.currentContentViewControllerForTesting is SettingsSectionViewController)
        #expect(texts.contains("Settings"))
        #expect(texts.contains("Strict Mode"))
        #expect(texts.contains("Appearance"))
    }

    @Test("Main shell calendar section is accessible only when calendar integration is enabled")
    @MainActor
    func mainShellCalendarSectionAvailability() {
        let appState = isolatedAppState(name: "calendarSectionAvailability")
        let controller = FreeMainViewController(
            appState: appState,
            initialSection: .focus,
            initialShowSidebar: true
        )
        _ = host(controller)

        controller.selectSectionForTesting(.calendar)
        #expect(controller.selectedSectionForTesting == .focus)

        appState.calendarIntegrationEnabled = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        controller.selectSectionForTesting(.calendar)
        #expect(controller.selectedSectionForTesting == .calendar)
        #expect(controller.currentContentViewControllerForTesting is CalendarSectionViewController)
    }
}
