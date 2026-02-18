import Foundation
import SwiftUI
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

        _ = app.menuIconColor
        _ = app.body
    }

    @Test("FreeApp reflects active menu state")
    func activeMenuState() {
        let appState = isolatedAppState(name: "activeMenuState")
        appState.isBlocking = true
        let app = FreeApp(appState: appState)

        #expect(app.menuStatusText == "Focus Mode: Active")
        #expect(app.isQuitDisabled == true)

        _ = app.menuIconColor
        _ = app.body
    }

    @Test("FreeApp default initializer builds scenes")
    func defaultInitializerBuildsScene() {
        let app = FreeApp()
        _ = app.body
    }
}
