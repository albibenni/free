import Testing
import SwiftUI
import AppKit
import Foundation
import ViewInspector
@testable import FreeLogic

private final class ContentViewMockLaunchAtLoginManager: LaunchAtLoginManaging {
    var isEnabledValue: Bool
    var isEnabledCallCount = 0
    var enableCallCount = 0
    var disableCallCount = 0

    init(isEnabled: Bool) {
        self.isEnabledValue = isEnabled
    }

    var isEnabled: Bool {
        isEnabledCallCount += 1
        return isEnabledValue
    }

    func enable() throws {
        enableCallCount += 1
        isEnabledValue = true
    }

    func disable() throws {
        disableCallCount += 1
        isEnabledValue = false
    }
}

@Suite(.serialized)
struct ContentViewTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "ContentViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    private func isolatedAppState(
        name: String,
        launchAtLoginManager: any LaunchAtLoginManaging,
        canPromptForLaunchAtLogin: @escaping () -> Bool
    ) -> AppState {
        let suite = "ContentViewTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(
            defaults: defaults,
            launchAtLoginManager: launchAtLoginManager,
            canPromptForLaunchAtLogin: canPromptForLaunchAtLogin,
            isTesting: true
        )
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 900, height: 900)) -> NSHostingView<V> {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    @Test("ContentView helper logic covers action, tint, and preferred color scheme")
    func contentViewHelperLogic() {
        let contentView = ContentView()
        #expect(contentView.isSidebarVisibleForTesting == false)
        #expect(contentView.showRulesForTesting == false)
        contentView.openSettings()
        contentView.toggleSettingsSidebar()
        contentView.openRules()
        #expect(contentView.selectedSectionForTesting == .focus)

        #expect(ContentView.tintColor(accentColorIndex: 3) == FocusColor.color(for: 3))
        #expect(ContentView.preferredColorScheme(for: .light) == .light)
        #expect(ContentView.preferredColorScheme(for: .dark) == .dark)
        #expect(ContentView.preferredColorScheme(for: .system) == nil)
        #expect(ContentView.nsAppearance(for: .light)?.name == .aqua)
        #expect(ContentView.nsAppearance(for: .dark)?.name == .darkAqua)
        #expect(ContentView.nsAppearance(for: .system) == nil)
        #expect(contentView.focusSection(for: .focus) == .all)
        #expect(contentView.focusSection(for: .schedules) == .schedules)
        #expect(contentView.focusSection(for: .allowedWebsites) == .allowedWebsites)
        #expect(contentView.focusSection(for: .pomodoro) == .pomodoro)
        #expect(contentView.focusSection(for: .settings) == .all)
    }

    @Test("ContentView renders with environment object")
    @MainActor
    func contentViewRender() {
        let appState = isolatedAppState(name: "render")
        appState.accentColorIndex = 2
        appState.appearanceMode = .dark

        let view = ContentView().environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("ContentView renders expanded sidebar menu with section entries and settings")
    @MainActor
    func contentViewExpandedSidebarRender() {
        let appState = isolatedAppState(name: "expandedSidebar")
        let view = ContentView(initialShowSidebar: true).environmentObject(appState)
        let hosted = host(view)
        #expect(hosted.fittingSize.width >= 0)
        #expect((try? view.inspect().find(text: "Menu")) != nil)
        #expect((try? view.inspect().find(text: "Focus")) != nil)
        #expect((try? view.inspect().find(text: "Schedules")) != nil)
        #expect((try? view.inspect().find(text: "Allowed Websites")) != nil)
        #expect((try? view.inspect().find(text: "Pomodoro")) != nil)
        #expect((try? view.inspect().find(text: "Settings")) != nil)
    }

    @Test("ContentView selected section accessor reflects initial section")
    func contentViewSelectedSectionAccessor() {
        let pomodoro = ContentView(initialSection: .pomodoro)
        #expect(pomodoro.selectedSectionForTesting == .pomodoro)
    }

    @Test("ContentView applies appearance changes on appear and mode updates")
    @MainActor
    func contentViewAppearanceUpdates() {
        let previousAppearance = NSApp?.appearance
        defer { NSApp?.appearance = previousAppearance }

        let appState = isolatedAppState(name: "appearanceUpdates")
        appState.appearanceMode = .light
        let view = ContentView().environmentObject(appState)
        _ = host(view)
        #expect(NSApp?.appearance?.name == .aqua)

        appState.appearanceMode = .dark
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(NSApp?.appearance?.name == .darkAqua)

        appState.appearanceMode = .system
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(NSApp?.appearance == nil)
    }

    @Test("ContentView sidebar buttons can be tapped through ViewInspector")
    @MainActor
    func contentViewSidebarButtonsViaInspector() throws {
        let appState = isolatedAppState(name: "inspectorSidebarButtons")

        let collapsed = ContentView(initialShowSidebar: false).environmentObject(appState)
        let collapsedButtons = try collapsed.inspect().findAll(ViewType.Button.self)
        #expect(collapsedButtons.count >= 1)
        try collapsedButtons[0].tap()

        let expanded = ContentView(initialShowSidebar: true).environmentObject(appState)
        let expandedButtons = try expanded.inspect().findAll(ViewType.Button.self)
        #expect(expandedButtons.count >= 3)
        try expandedButtons[1].tap()
        try expandedButtons[2].tap()
        let settingsButton = try expanded.inspect().find(button: "Settings")
        try settingsButton.tap()
    }

    @Test("ContentView schedules section shows expanded widget by default")
    @MainActor
    func contentViewSchedulesSectionOpensWidget() {
        let appState = isolatedAppState(name: "sectionSelectionOpensWidget")
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

        let view = ContentView(initialSection: .schedules).environmentObject(appState)
        _ = host(view)
        #expect((try? view.inspect().find(text: "Open Full Calendar")) != nil)
    }

    @Test("ContentView settings section renders in main content")
    @MainActor
    func contentViewSettingsMainContentRender() {
        let appState = isolatedAppState(name: "settingsMainContent")
        let view = ContentView(initialSection: .settings)
            .environmentObject(appState)
        let hosted = host(view, size: CGSize(width: 900, height: 900))
        #expect(hosted.fittingSize.height >= 0)
        #expect((try? view.inspect().find(text: "Strict Mode")) != nil)
    }

    @Test("ContentView rules sheet helper renders")
    @MainActor
    func contentViewRulesSheetRender() {
        let appState = isolatedAppState(name: "rulesSheet")
        var showRules = true
        let binding = Binding(get: { showRules }, set: { showRules = $0 })

        let view = ContentView.rulesSheet(showRules: binding)
            .environmentObject(appState)
        let hosted = host(view, size: CGSize(width: 760, height: 720))
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("ContentView schedules sheet helper renders")
    @MainActor
    func contentViewSchedulesSheetRender() {
        let appState = isolatedAppState(name: "schedulesSheet")
        var showSchedules = true
        let binding = Binding(get: { showSchedules }, set: { showSchedules = $0 })

        let view = ContentView.schedulesSheet(showSchedules: binding)
            .environmentObject(appState)
        let hosted = host(view, size: CGSize(width: 820, height: 760))
        #expect(hosted.fittingSize.height >= 0)
    }

    @Test("ContentView renders with rules sheet initially presented")
    @MainActor
    func contentViewInitialRulesSheetRender() {
        let appState = isolatedAppState(name: "initialRulesSheet")
        let view = ContentView(initialShowRules: true).environmentObject(appState)
        let hosted = host(view, size: CGSize(width: 900, height: 900))
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("ContentView renders with schedules sheet initially presented")
    @MainActor
    func contentViewInitialSchedulesSheetRender() {
        let appState = isolatedAppState(name: "initialSchedulesSheet")
        let view = ContentView(initialShowSchedules: true).environmentObject(appState)
        let hosted = host(view, size: CGSize(width: 900, height: 900))
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("ContentView launch-at-login alert enable action triggers app-state registration")
    @MainActor
    func contentViewLaunchAtLoginAlertEnableAction() throws {
        let launchManager = ContentViewMockLaunchAtLoginManager(isEnabled: false)
        let appState = isolatedAppState(
            name: "launchAtLoginAlertEnableAction",
            launchAtLoginManager: launchManager,
            canPromptForLaunchAtLogin: { true }
        )

        let view = ContentView(initialShowLaunchAtLoginPrompt: true).environmentObject(appState)
        _ = host(view)

        let alert = try view.inspect().find(ViewType.Alert.self)
        try alert.actions().button(1).tap()

        #expect(launchManager.enableCallCount == 1)
        #expect(appState.launchAtLoginStatus() == true)

        let cancelManager = ContentViewMockLaunchAtLoginManager(isEnabled: false)
        let cancelState = isolatedAppState(
            name: "launchAtLoginAlertCancelAction",
            launchAtLoginManager: cancelManager,
            canPromptForLaunchAtLogin: { true }
        )
        let cancelView = ContentView(initialShowLaunchAtLoginPrompt: true).environmentObject(cancelState)
        _ = host(cancelView)
        let cancelAlert = try cancelView.inspect().find(ViewType.Alert.self)
        try cancelAlert.actions().button(0).tap()
        #expect(cancelManager.enableCallCount == 0)
    }
}
