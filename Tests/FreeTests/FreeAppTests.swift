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

    @Test("FreeApp derives application name from bundle metadata with process fallback")
    func applicationNameResolution() {
        #expect(
            FreeApp.applicationName(
                bundleInfo: ["CFBundleDisplayName": "Free Display"],
                processName: "Proc"
            ) == "Free Display"
        )
        #expect(
            FreeApp.applicationName(
                bundleInfo: ["CFBundleName": "Free Bundle"],
                processName: "Proc"
            ) == "Free Bundle"
        )
        #expect(
            FreeApp.applicationName(
                bundleInfo: [:],
                processName: "Proc"
            ) == "Proc"
        )
    }

    @Test("FreeApp main menu includes Quit item bound to command-Q")
    func mainMenuContainsQuitShortcut() {
        let menu = FreeApp.makeMainMenu(appName: "Free")

        #expect(menu.items.count == 2)
        let appMenu = menu.items.first?.submenu
        #expect(appMenu != nil)

        let quitItem = appMenu?.items.first(where: { $0.title == "Quit Free" })
        #expect(quitItem != nil)
        #expect(quitItem?.action == #selector(NSApplication.terminate(_:)))
        #expect(quitItem?.keyEquivalent == "q")
        #expect(quitItem?.keyEquivalentModifierMask == [.command])

        let editMenu = menu.items.last?.submenu
        let pasteItem = editMenu?.items.first(where: { $0.title == "Paste" })
        #expect(pasteItem?.action == #selector(NSText.paste(_:)))
        #expect(pasteItem?.keyEquivalent == "v")
        #expect(pasteItem?.keyEquivalentModifierMask == [.command])
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
