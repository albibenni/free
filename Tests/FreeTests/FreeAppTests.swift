import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct FreeAppTests {
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

    @Test("FreeApp resolves application name from Bundle/ProcessInfo wrapper")
    func bundleAndProcessNameWrapper() {
        let result = FreeApp.applicationName(bundle: .main, processInfo: .processInfo)
        #expect(result.isEmpty == false)
    }

    @MainActor
    @Test("FreeApp launch/start interface and appearance updates are stable")
    func launchStartAndAppearanceLifecycle() {
        let environment = ProcessInfo.processInfo.environment
        if environment["FREE_COVERAGE_MODE"] == "1",
           environment["FREE_RUN_APPKIT_LIFECYCLE_UNDER_COVERAGE"] != "1" {
            // This path intermittently crashes swiftpm-testing-helper under coverage instrumentation.
            // It remains fully exercised in normal `swift test` runs.
            #expect(Bool(true))
            return
        }

        resetSharedApplicationState()
        defer { resetSharedApplicationState() }

        let appState = isolatedAppState(name: "launchAndStartInterfaceLifecycle")
        let appDelegate = AppDelegate()

        var madeMainViewControllerCount = 0
        var madeStatusControllerCount = 0
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
            }
        )

        app.launch(application: NSApplication.shared)
        #expect(NSApplication.shared.delegate === appDelegate)
        #expect(appDelegate.onApplicationDidFinishLaunching != nil)

        app.startInterface(application: NSApplication.shared)
        #expect(app.mainWindowController != nil)
        #expect(app.statusItemController != nil)
        #expect(NSApplication.shared.mainMenu != nil)
        #expect(madeMainViewControllerCount == 1)
        #expect(madeStatusControllerCount == 1)
        #expect(capturedQuitAction != nil)

        // Calling again should reuse previously created shell objects.
        app.startInterface(application: NSApplication.shared)
        #expect(madeMainViewControllerCount == 1)
        #expect(madeStatusControllerCount == 1)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let content = NSView(frame: window.contentView?.bounds ?? .zero)
        let child = NSView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        content.addSubview(child)
        window.contentView = content

        app.applyMacOSAppearance(.dark)
        #expect(NSApp.appearance?.name == .darkAqua)
        #expect(window.appearance?.name == .darkAqua)
        #expect(content.needsLayout)
        #expect(content.needsDisplay)
        #expect(child.needsDisplay)

        app.applyMacOSAppearance(.system)
        #expect(NSApp.appearance == nil)

    }
}
