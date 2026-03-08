import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct FreeAppTests {
    private struct SharedAppSnapshot {
        let delegate: NSApplicationDelegate?
        let mainMenu: NSMenu?
        let appearance: NSAppearance?
    }

    private func isolatedAppState(name: String) -> AppState {
        let suite = "FreeAppTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func resetSharedApplicationState() {
        let application = NSApplication.shared
        application.windows.forEach { window in
            window.orderOut(nil)
            window.close()
        }
        application.mainMenu = nil
        application.delegate = nil
        application.appearance = nil
    }

    @MainActor
    private func snapshotSharedApplicationState() -> SharedAppSnapshot {
        let application = NSApplication.shared
        return SharedAppSnapshot(
            delegate: application.delegate,
            mainMenu: application.mainMenu,
            appearance: application.appearance
        )
    }

    @MainActor
    private func restoreSharedApplicationState(_ snapshot: SharedAppSnapshot) {
        let application = NSApplication.shared
        application.mainMenu = snapshot.mainMenu
        application.delegate = snapshot.delegate
        application.appearance = snapshot.appearance
    }

    @MainActor
    private func drainMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }

    @MainActor
    private func withIsolatedAppKitState(_ body: () -> Void) {
        let snapshot = snapshotSharedApplicationState()
        resetSharedApplicationState()
        defer {
            drainMainRunLoop()
            resetSharedApplicationState()
            restoreSharedApplicationState(snapshot)
            drainMainRunLoop()
        }
        body()
    }

    @MainActor
    @Test("FreeApp reflects inactive menu state")
    func inactiveMenuState() {
        withIsolatedAppKitState {
            let appState = isolatedAppState(name: "inactiveMenuState")
            appState.isBlocking = false
            let app = FreeApp(appState: appState)

            #expect(app.menuStatusText == "Focus Mode: Inactive")
            #expect(app.isQuitDisabled == false)
            #expect(app.menuIconColor == .labelColor)
        }
    }

    @MainActor
    @Test("FreeApp reflects active menu state")
    func activeMenuState() {
        withIsolatedAppKitState {
            let appState = isolatedAppState(name: "activeMenuState")
            appState.isBlocking = true
            let app = FreeApp(appState: appState)

            #expect(app.menuStatusText == "Focus Mode: Active")
            #expect(app.isQuitDisabled == true)
            #expect(app.menuIconColor == .systemGreen)
        }
    }

    @MainActor
    @Test("FreeApp appearance mapping mirrors app settings")
    func appearanceMapping() {
        withIsolatedAppKitState {
            #expect(FreeApp.nsAppearance(for: .system) == nil)
            #expect(FreeApp.nsAppearance(for: .light)?.name == .aqua)
            #expect(FreeApp.nsAppearance(for: .dark)?.name == .darkAqua)
        }
    }

    @MainActor
    @Test("FreeApp derives application name from bundle metadata with process fallback")
    func applicationNameResolution() {
        withIsolatedAppKitState {
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
    }

    @MainActor
    @Test("FreeApp main menu includes Quit item bound to command-Q")
    func mainMenuContainsQuitShortcut() {
        withIsolatedAppKitState {
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
    }

    @MainActor
    @Test("FreeApp default initializer can be created")
    func defaultInitializerBuildsAppController() {
        withIsolatedAppKitState {
            let app = FreeApp()
            #expect(
                app.menuStatusText == "Focus Mode: Active"
                    || app.menuStatusText == "Focus Mode: Inactive"
            )
        }
    }

    @MainActor
    @Test("FreeApp initializer uses default controller factories when omitted")
    func initializerDefaultFactoryArguments() {
        withIsolatedAppKitState {
            let appState = isolatedAppState(name: "defaultFactories")
            let app = FreeApp(
                appState: appState,
                appDelegate: AppDelegate()
            )
            #expect(app.menuStatusText == "Focus Mode: Inactive")
        }
    }

    @MainActor
    @Test("FreeApp resolves application name from Bundle/ProcessInfo wrapper")
    func bundleAndProcessNameWrapper() {
        withIsolatedAppKitState {
            let result = FreeApp.applicationName(bundle: .main, processInfo: .processInfo)
            #expect(result.isEmpty == false)
        }
    }

    @MainActor
    @Test("FreeApp launch/start interface and appearance updates are stable")
    func launchStartAndAppearanceLifecycle() {
        withIsolatedAppKitState {
            let appState = isolatedAppState(name: "launchAndStartInterfaceLifecycle")
            let appDelegate = AppDelegate()

            var madeMainViewControllerCount = 0
            var madeStatusControllerCount = 0
            var presentMainWindowCallCount = 0
            var capturedQuitAction: (() -> Void)?

            let app = FreeApp(
                appState: appState,
                appDelegate: appDelegate,
                makeMainViewController: { state in
                    madeMainViewControllerCount += 1
                    return FreeMainViewController(appState: state)
                },
                makeStatusItemController: { onQuit in
                    madeStatusControllerCount += 1
                    capturedQuitAction = onQuit
                    return FreeStatusItemController(onQuit: {})
                },
                presentMainWindow: { _, _ in
                    presentMainWindowCallCount += 1
                }
            )

            app.launch(application: NSApplication.shared)
            #expect(NSApplication.shared.delegate === appDelegate)
            #expect(appDelegate.onApplicationDidFinishLaunching != nil)
            appDelegate.onApplicationDidFinishLaunching?()

            app.startInterface(application: NSApplication.shared)
            #expect(app.mainWindowController != nil)
            #expect(app.statusItemController != nil)
            #expect(NSApplication.shared.mainMenu != nil)
            #expect(madeMainViewControllerCount == 1)
            #expect(madeStatusControllerCount == 1)
            #expect(presentMainWindowCallCount == 1)
            #expect(capturedQuitAction != nil)

            // Calling again should reuse previously created shell objects.
            app.startInterface(application: NSApplication.shared)
            #expect(madeMainViewControllerCount == 1)
            #expect(madeStatusControllerCount == 1)
            #expect(presentMainWindowCallCount == 1)

            app.applyMacOSAppearance(.dark)
            #expect(NSApp.appearance?.name == .darkAqua)

            app.applyMacOSAppearance(.system)
            #expect(NSApp.appearance == nil)

            appState.isBlocking.toggle()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            appState.appearanceMode = .light
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            appState.appearanceMode = .dark
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

}
