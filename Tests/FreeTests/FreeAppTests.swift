import AppKit
import Foundation
import Testing

@testable import FreeLogic

struct FreeAppTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "FreeAppTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @Test("FreeApp reflects inactive menu state")
    func inactiveMenuState() {
        let appState = isolatedAppState(name: "inactiveMenuState")
        appState.isBlocking = false
        let app = FreeApp(appState: appState)

        #expect(app.menuStatusText == "Focus Mode: Inactive")
        #expect(app.isQuitDisabled == false)
        #expect(app.menuIconColor == .labelColor)
    }

    @Test("FreeApp reflects active menu state")
    func activeMenuState() {
        let appState = isolatedAppState(name: "activeMenuState")
        appState.isBlocking = true
        let app = FreeApp(appState: appState)

        #expect(app.menuStatusText == "Focus Mode: Active")
        #expect(app.isQuitDisabled == true)
        #expect(app.menuIconColor == .systemGreen)
    }

    @Test("FreeApp appearance mapping mirrors app settings")
    func appearanceMapping() {
        #expect(FreeApp.nsAppearance(for: .system) == nil)
        #expect(FreeApp.nsAppearance(for: .light)?.name == .aqua)
        #expect(FreeApp.nsAppearance(for: .dark)?.name == .darkAqua)
    }

    @Test("FreeApp default initializer can be created")
    func defaultInitializerBuildsAppController() {
        let app = FreeApp()
        #expect(
            app.menuStatusText == "Focus Mode: Active"
                || app.menuStatusText == "Focus Mode: Inactive"
        )
    }
}
