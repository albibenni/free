import AppKit
import Combine

final class FreeApp {
    let appState: AppState
    let appDelegate: AppDelegate

    private let makeMainViewController: (AppState) -> FreeMainViewController
    private let makeStatusItemController: (@escaping () -> Void) -> FreeStatusItemController
    private let presentMainWindow: (FreeMainWindowController, FreeMainViewController) -> Void

    private(set) var mainWindowController: FreeMainWindowController?
    private(set) var statusItemController: FreeStatusItemController?

    private var cancellables: Set<AnyCancellable> = []
    private var hasBoundState = false
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var lastStatusRenderState: StatusRenderState?

    private struct StatusRenderState: Equatable {
        let statusText: String
        let topBarText: String
        let isQuitDisabled: Bool
        let isBlocking: Bool
    }

    init(
        appState: AppState = AppState(defaults: .standard),
        appDelegate: AppDelegate = AppDelegate(),
        makeMainViewController: @escaping (AppState) -> FreeMainViewController = {
            FreeMainViewController(appState: $0)
        },
        makeStatusItemController: @escaping (@escaping () -> Void) -> FreeStatusItemController = {
            FreeStatusItemController(onQuit: $0)
        },
        presentMainWindow: @escaping (FreeMainWindowController, FreeMainViewController) -> Void = {
            windowController, rootViewController in
            windowController.showWindow(nil)
            windowController.window?.makeKeyAndOrderFront(nil)
            rootViewController.presentLaunchAtLoginPromptIfNeeded()
        }
    ) {
        self.appState = appState
        self.appDelegate = appDelegate
        self.makeMainViewController = makeMainViewController
        self.makeStatusItemController = makeStatusItemController
        self.presentMainWindow = presentMainWindow
    }

    var menuStatusText: String {
        let focusState = appState.isBlocking ? "Active" : "Inactive"
        let details = menuDetailSegments(now: Date())
        return (["Focus Mode: \(focusState)"] + details).joined(separator: "\n")
    }

    var isQuitDisabled: Bool {
        appState.isBlocking
    }

    var menuIconColor: NSColor {
        appState.isBlocking ? .systemGreen : .labelColor
    }

    var topBarStatusText: String {
        ""
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
            bundleInfo: bundle.infoDictionary,
            processName: processInfo.processName
        )
    }

    static func applicationName(bundleInfo: [String: Any]?, processName: String) -> String {
        guard let bundleInfo else { return processName }
        return applicationName(bundleInfo: bundleInfo, processName: processName)
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

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        undoItem.target = nil
        editMenu.addItem(undoItem)

        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        redoItem.target = nil
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())

        let cutItem = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        cutItem.target = nil
        editMenu.addItem(cutItem)

        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        copyItem.target = nil
        editMenu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        pasteItem.target = nil
        editMenu.addItem(pasteItem)

        let selectAllItem = NSMenuItem(
            title: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        selectAllItem.target = nil
        editMenu.addItem(selectAllItem)

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
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
            presentMainWindow(windowController, rootViewController)
        }

        if statusItemController == nil {
            statusItemController = makeStatusItemController(Self.quitAction())
        }
        if didBecomeActiveObserver == nil {
            didBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.appState.monitor?.checkPermissions(prompt: false)
            }
        }
        statusItemController?.setOpenAppHandler { [weak self, weak application] in
            guard let self, let application else { return }
            self.mainWindowController?.showWindow(nil)
            self.mainWindowController?.window?.makeKeyAndOrderFront(nil)
            self.mainWindowController?.window?.orderFrontRegardless()
            application.activate(ignoringOtherApps: true)
        }

        bindStateIfNeeded()
        applyMacOSAppearance(appState.appearanceMode)
        updateStatusItem()
        application.activate(ignoringOtherApps: true)
    }

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
    }

    func applyMacOSAppearance(_ mode: AppearanceMode) {
        let appearance = Self.nsAppearance(for: mode)
        NSApp.appearance = appearance

        for window in NSApp.windows {
            window.appearance = appearance
            window.contentView?.needsLayout = true
            window.contentView?.needsDisplay = true
        }
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

        Publishers.MergeMany(
            appState.$isUnblockable.map { _ in () }.eraseToAnyPublisher(),
            appState.$isPaused.map { _ in () }.eraseToAnyPublisher(),
            appState.$schedules.map { _ in () }.eraseToAnyPublisher(),
            appState.$ruleSets.map { _ in () }.eraseToAnyPublisher(),
            appState.$activeRuleSetId.map { _ in () }.eraseToAnyPublisher(),
            appState.$pomodoroStatus.map { _ in () }.eraseToAnyPublisher(),
            appState.$pomodoroRemaining.map { _ in () }.eraseToAnyPublisher(),
            appState.$calendarIntegrationEnabled.map { _ in () }.eraseToAnyPublisher(),
            appState.calendarProvider.objectWillChange.map { _ in () }.eraseToAnyPublisher()
        )
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
        let nextState = StatusRenderState(
            statusText: menuStatusText,
            topBarText: topBarStatusText,
            isQuitDisabled: isQuitDisabled,
            isBlocking: appState.isBlocking
        )
        guard nextState != lastStatusRenderState else { return }
        lastStatusRenderState = nextState

        statusItemController?.update(
            statusText: nextState.statusText,
            topBarText: nextState.topBarText,
            isQuitDisabled: nextState.isQuitDisabled,
            iconColor: nextState.isBlocking ? .systemGreen : .labelColor
        )
    }

    private func menuDetailSegments(now: Date) -> [String] {
        var segments: [String] = [calendarSegment(now: now)]

        if appState.isBlocking {
            segments.append("Allowed List: \(appState.currentPrimaryRuleSetName)")
        }

        if appState.isUnblockable {
            segments.append("Unbreakable")
        }

        if appState.pomodoroStatus != .none {
            let phase = appState.pomodoroStatus == .focus ? "Focus" : "Break"
            segments.append("Pomodoro: \(phase) \(appState.timeString(time: appState.pomodoroRemaining))")
        }

        return segments
    }

    private func calendarSegment(now: Date) -> String {
        guard appState.calendarIntegrationEnabled else { return "Calendar: Off" }

        var nextEvent: ExternalEvent?
        for event in appState.calendarProvider.events {
            if event.isActive(at: now) {
                return "Calendar: Active"
            }
            if event.startDate > now {
                if let currentNext = nextEvent {
                    if event.startDate < currentNext.startDate {
                        nextEvent = event
                    }
                } else {
                    nextEvent = event
                }
            }
        }
        if let nextEvent {
            return "Calendar: Next \(Self.statusTimeFormatter.string(from: nextEvent.startDate))"
        }
        return "Calendar: None"
    }

    private static let statusTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
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
