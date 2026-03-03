import AppKit
import Testing

@testable import FreeLogic

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
        let controller = FreeMainViewController(
            appState: isolatedAppState(name: "sidebarSelection"),
            initialSection: .focus,
            initialShowSidebar: true
        )

        controller.loadViewIfNeeded()

        #expect(controller.selectedSectionForTesting == .focus)
        #expect(controller.isSidebarButtonSelectedForTesting(.focus))
        #expect(controller.isSidebarButtonSelectedForTesting(.pomodoro) == false)

        controller.selectSectionForTesting(.pomodoro)

        #expect(controller.selectedSectionForTesting == .pomodoro)
        #expect(controller.isSidebarButtonSelectedForTesting(.focus) == false)
        #expect(controller.isSidebarButtonSelectedForTesting(.pomodoro))
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
}
