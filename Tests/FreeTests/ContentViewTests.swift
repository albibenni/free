import Testing
import SwiftUI
import AppKit
import Foundation
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
        contentView.openSettings()

        var showSettings = false
        let settingsBinding = Binding(get: { showSettings }, set: { showSettings = $0 })
        let openSettings = ContentView.makeShowSettingsAction(showSettings: settingsBinding)
        openSettings()
        #expect(showSettings == true)

        #expect(ContentView.tintColor(accentColorIndex: 3) == FocusColor.color(for: 3))
        #expect(ContentView.preferredColorScheme(for: .light) == .light)
        #expect(ContentView.preferredColorScheme(for: .dark) == .dark)
        #expect(ContentView.preferredColorScheme(for: .system) == nil)
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

    @Test("ContentView settings sheet helper renders")
    @MainActor
    func contentViewSettingsSheetRender() {
        let appState = isolatedAppState(name: "settingsSheet")
        var showSettings = true
        let binding = Binding(get: { showSettings }, set: { showSettings = $0 })

        let view = ContentView.settingsSheet(showSettings: binding)
            .environmentObject(appState)
        let hosted = host(view, size: CGSize(width: 500, height: 420))
        #expect(hosted.fittingSize.height >= 0)
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

    @Test("ContentView renders with settings sheet initially presented")
    @MainActor
    func contentViewInitialSettingsSheetRender() {
        let appState = isolatedAppState(name: "initialSettingsSheet")
        let view = ContentView(initialShowSettings: true).environmentObject(appState)
        let hosted = host(view, size: CGSize(width: 900, height: 900))
        #expect(hosted.fittingSize.width >= 0)
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
}
