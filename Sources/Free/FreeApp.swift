import AppKit
import Combine

final class FreeApp {
    let appState: AppState
    let appDelegate: AppDelegate

    private let makeMainViewController: (AppState) -> FreeMainViewController
    private let makeStatusItemController: (@escaping () -> Void) -> FreeStatusItemController

    private(set) var mainWindowController: FreeMainWindowController?
    private(set) var statusItemController: FreeStatusItemController?

    private var cancellables: Set<AnyCancellable> = []
    private var hasBoundState = false

    init(
        appState: AppState = AppState(defaults: .standard),
        appDelegate: AppDelegate = AppDelegate(),
        makeMainViewController: @escaping (AppState) -> FreeMainViewController = {
            FreeMainViewController(appState: $0)
        },
        makeStatusItemController: @escaping (@escaping () -> Void) -> FreeStatusItemController = {
            FreeStatusItemController(onQuit: $0)
        }
    ) {
        self.appState = appState
        self.appDelegate = appDelegate
        self.makeMainViewController = makeMainViewController
        self.makeStatusItemController = makeStatusItemController
    }

    var menuStatusText: String {
        appState.isBlocking ? "Focus Mode: Active" : "Focus Mode: Inactive"
    }

    var isQuitDisabled: Bool {
        appState.isBlocking
    }

    var menuIconColor: NSColor {
        appState.isBlocking ? .systemGreen : .labelColor
    }

    static func quitAction() -> () -> Void {
        FreeAppRuntime.quitApplication
    }

    static func nsAppearance(for mode: AppearanceMode) -> NSAppearance? {
        switch mode {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    static func applicationName(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> String {
        applicationName(
            bundleInfo: bundle.infoDictionary ?? [:],
            processName: processInfo.processName
        )
    }

    static func applicationName(bundleInfo: [String: Any], processName: String) -> String {
        if let displayName = bundleInfo["CFBundleDisplayName"] as? String,
           !displayName.isEmpty {
            return displayName
        }
        if let bundleName = bundleInfo["CFBundleName"] as? String,
           !bundleName.isEmpty {
            return bundleName
        }
        return processName
    }

    static func makeMainMenu(appName: String) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: appName)

        let aboutItem = NSMenuItem(
            title: "About \(appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = NSApplication.shared
        appMenu.addItem(aboutItem)
        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide \(appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = NSApplication.shared
        appMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        hideOthersItem.target = NSApplication.shared
        appMenu.addItem(hideOthersItem)

        let showAllItem = NSMenuItem(
            title: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        showAllItem.target = NSApplication.shared
        appMenu.addItem(showAllItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApplication.shared
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        return mainMenu
    }

    func launch(application: NSApplication = .shared) {
        application.setActivationPolicy(.regular)
        appDelegate.onApplicationDidFinishLaunching = { [weak self, weak application] in
            guard let self, let application else { return }
            self.startInterface(application: application)
        }
        application.delegate = appDelegate
    }

    func startInterface(application: NSApplication = .shared) {
        application.mainMenu = Self.makeMainMenu(
            appName: Self.applicationName()
        )

        if mainWindowController == nil {
            let rootViewController = makeMainViewController(appState)
            let windowController = FreeMainWindowController(rootViewController: rootViewController)
            mainWindowController = windowController
            windowController.showWindow(nil)
            windowController.window?.makeKeyAndOrderFront(nil)
            rootViewController.presentLaunchAtLoginPromptIfNeeded()
        }

        if statusItemController == nil {
            statusItemController = makeStatusItemController(Self.quitAction())
        }

        bindStateIfNeeded()
        applyMacOSAppearance(appState.appearanceMode)
        updateStatusItem()
        application.activate(ignoringOtherApps: true)
    }

    func applyMacOSAppearance(_ mode: AppearanceMode) {
        NSApp.appearance = Self.nsAppearance(for: mode)
    }

    private func bindStateIfNeeded() {
        guard !hasBoundState else { return }
        hasBoundState = true

        appState.$isBlocking
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)

        appState.$appearanceMode
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                self?.applyMacOSAppearance(mode)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        statusItemController?.update(
            statusText: menuStatusText,
            isQuitDisabled: isQuitDisabled,
            iconColor: menuIconColor
        )
    }
}

#if !SWIFT_PACKAGE
@main
enum FreeAppMain {
    static func main() {
        let application = NSApplication.shared
        let app = FreeApp()
        app.launch(application: application)
        withExtendedLifetime(app) {
            application.run()
        }
    }
}
#endif
