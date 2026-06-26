import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
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
    private func drainMainRunLoop() async throws {
        try await Task.sleep(nanoseconds: 100000000)
    }

    @MainActor
    private func withIsolatedAppKitState(_ body: () async throws -> Void) async throws {
        let snapshot = snapshotSharedApplicationState()
        resetSharedApplicationState()
        do {
            try await body()
        } catch {
            try await drainMainRunLoop()
            resetSharedApplicationState()
            restoreSharedApplicationState(snapshot)
            try await drainMainRunLoop()
            throw error
        }
        try await drainMainRunLoop()
        resetSharedApplicationState()
        restoreSharedApplicationState(snapshot)
        try await drainMainRunLoop()
    }

    @MainActor
    @Test("FreeApp reflects inactive menu state")
    func inactiveMenuState() async throws {
        try await withIsolatedAppKitState {
            let appState = isolatedAppState(name: "inactiveMenuState")
            appState.isBlocking = false
            let app = FreeApp(appState: appState, appDelegate: AppDelegate())

            #expect(app.menuStatusText.hasPrefix("Focus Mode: Inactive"))
            #expect(app.isQuitDisabled == false)
            #expect(app.menuIconColor == .labelColor)
        }
    }

    @MainActor
    @Test("FreeApp reflects active menu state")
    func activeMenuState() async throws {
        try await withIsolatedAppKitState {
            let appState = isolatedAppState(name: "activeMenuState")
            appState.isBlocking = true
            let app = FreeApp(appState: appState, appDelegate: AppDelegate())

            #expect(app.menuStatusText.hasPrefix("Focus Mode: Active"))
            #expect(app.isQuitDisabled == true)
            #expect(app.menuIconColor == .systemGreen)
        }
    }

    @MainActor
    @Test("FreeApp menu status summary includes focus, calendar, list, unbreakable and pomodoro details")
    func menuStatusSummaryIncludesRequestedSignals() async throws {
        try await withIsolatedAppKitState {
            let suite = "FreeAppTests.topBarStatusSummaryIncludesRequestedSignals"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let calendar = MockCalendarManager()
            let now = Date()
            calendar.events = [
                ExternalEvent(
                    id: "active-calendar-event",
                    title: "Deep Work",
                    startDate: now.addingTimeInterval(-300),
                    endDate: now.addingTimeInterval(900)
                )
            ]

            let appState = AppState(defaults: defaults, calendar: calendar, isTesting: true)
            let list = RuleSet(name: "Default", urls: ["https://example.com/*"])
            appState.ruleSets = [list]
            appState.activeRuleSetId = list.id
            appState.isBlocking = true
            appState.calendarIntegrationEnabled = true
            appState.isStrict = true
            appState.pomodoroStatus = .focus
            appState.pomodoroRemaining = 120

            let app = FreeApp(appState: appState, appDelegate: AppDelegate())
            let menu = app.menuStatusText

            #expect(menu.contains("Focus Mode: Active"))
            #expect(menu.contains("Calendar: Active"))
            #expect(menu.contains("Allowed List:"))
            #expect(menu.contains("Unbreakable"))
            #expect(menu.contains("Pomodoro: Focus"))
            #expect(app.topBarStatusText.isEmpty)
        }
    }

    @MainActor
    @Test("FreeApp menu status summary shows next calendar schedule when no event is currently active")
    func menuStatusSummaryShowsNextCalendarEvent() async throws {
        try await withIsolatedAppKitState {
            let suite = "FreeAppTests.topBarStatusSummaryShowsNextCalendarEvent"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let calendar = MockCalendarManager()
            calendar.events = [
                ExternalEvent(
                    id: "next-calendar-event",
                    title: "Planning",
                    startDate: Date().addingTimeInterval(1800),
                    endDate: Date().addingTimeInterval(3600)
                )
            ]

            let appState = AppState(defaults: defaults, calendar: calendar, isTesting: true)
            appState.calendarIntegrationEnabled = true
            let app = FreeApp(appState: appState, appDelegate: AppDelegate())

            #expect(app.menuStatusText.contains("Calendar: Next"))
            #expect(app.topBarStatusText.isEmpty)
        }
    }

    @MainActor
    @Test("FreeApp menu status summary chooses earliest upcoming calendar event from unsorted events")
    func menuStatusSummarySortsCalendarEventsBeforePickingNext() async throws {
        try await withIsolatedAppKitState {
            let suite = "FreeAppTests.menuStatusSummarySortsCalendarEventsBeforePickingNext"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let calendar = MockCalendarManager()
            let now = Date()
            let earliest = now.addingTimeInterval(900)
            calendar.events = [
                ExternalEvent(
                    id: "later-calendar-event",
                    title: "Later",
                    startDate: now.addingTimeInterval(3600),
                    endDate: now.addingTimeInterval(4200)
                ),
                ExternalEvent(
                    id: "earliest-calendar-event",
                    title: "Earliest",
                    startDate: earliest,
                    endDate: now.addingTimeInterval(1500)
                ),
            ]

            let appState = AppState(defaults: defaults, calendar: calendar, isTesting: true)
            appState.calendarIntegrationEnabled = true
            let app = FreeApp(appState: appState, appDelegate: AppDelegate())
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            let expected = formatter.string(from: earliest)

            #expect(app.menuStatusText.contains("Calendar: Next \(expected)"))
        }
    }

    @MainActor
    @Test("FreeApp menu status summary shows calendar none when integration is enabled with no events")
    func menuStatusSummaryShowsCalendarNone() async throws {
        try await withIsolatedAppKitState {
            let suite = "FreeAppTests.menuStatusSummaryShowsCalendarNone"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let calendar = MockCalendarManager()
            calendar.events = []

            let appState = AppState(defaults: defaults, calendar: calendar, isTesting: true)
            appState.calendarIntegrationEnabled = true
            let app = FreeApp(appState: appState, appDelegate: AppDelegate())

            #expect(app.menuStatusText.contains("Calendar: None"))
        }
    }

    @MainActor
    @Test("FreeApp menu status summary includes pomodoro break phase")
    func menuStatusSummaryIncludesPomodoroBreak() async throws {
        try await withIsolatedAppKitState {
            let appState = isolatedAppState(name: "menuStatusSummaryIncludesPomodoroBreak")
            appState.pomodoroStatus = .breakTime
            appState.pomodoroRemaining = 90
            let app = FreeApp(appState: appState, appDelegate: AppDelegate())

            #expect(app.menuStatusText.contains("Pomodoro: Break"))
        }
    }

    @MainActor
    @Test("FreeApp appearance mapping mirrors app settings")
    func appearanceMapping() async throws {
        try await withIsolatedAppKitState {
            #expect(FreeApp.nsAppearance(for: .system) == nil)
            #expect(FreeApp.nsAppearance(for: .light)?.name == .aqua)
            #expect(FreeApp.nsAppearance(for: .dark)?.name == .darkAqua)
        }
    }

    @MainActor
    @Test("FreeApp derives application name from bundle metadata with process fallback")
    func applicationNameResolution() async throws {
        try await withIsolatedAppKitState {
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
            #expect(
                FreeApp.applicationName(
                    bundleInfo: ["CFBundleDisplayName": "", "CFBundleName": "Bundle Name"],
                    processName: "Proc"
                ) == "Bundle Name"
            )
            #expect(
                FreeApp.applicationName(
                    bundleInfo: ["CFBundleDisplayName": "", "CFBundleName": ""],
                    processName: "Proc"
                ) == "Proc"
            )
        }
    }

    @MainActor
    @Test("FreeApp main menu includes Quit item bound to command-Q")
    func mainMenuContainsQuitShortcut() async throws {
        try await withIsolatedAppKitState {
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
    func defaultInitializerBuildsAppController() async throws {
        try await withIsolatedAppKitState {
            let app = FreeApp(appState: isolatedAppState(name: "defaultInit"), appDelegate: AppDelegate())
            #expect(app.menuStatusText.hasPrefix("Focus Mode:"))
        }
    }

    @MainActor
    @Test("FreeApp default factories build interface objects on first start")
    func defaultFactoriesBuildInterfaceObjects() async throws {
        try await withIsolatedAppKitState {
            let appState = isolatedAppState(name: "defaultFactoriesBuildInterfaceObjects")
            let app = FreeApp(appState: appState, appDelegate: AppDelegate())

            app.startInterface(application: NSApplication.shared)

            #expect(app.mainWindowController != nil)
            #expect(app.statusItemController != nil)
            #expect(NSApplication.shared.mainMenu != nil)
        }
    }

    @MainActor
    @Test("FreeApp initializer uses default controller factories when omitted")
    func initializerDefaultFactoryArguments() async throws {
        try await withIsolatedAppKitState {
            let appState = isolatedAppState(name: "defaultFactories")
            let app = FreeApp(
                appState: appState,
                appDelegate: AppDelegate()
            )
            #expect(app.menuStatusText.hasPrefix("Focus Mode: Inactive"))
        }
    }

    @MainActor
    @Test("FreeApp resolves application name from Bundle/ProcessInfo wrapper")
    func bundleAndProcessNameWrapper() async throws {
        try await withIsolatedAppKitState {
            let result = FreeApp.applicationName(bundle: .main, processInfo: .processInfo)
            #expect(result.isEmpty == false)
        }
    }

    @MainActor
    @Test("FreeApp falls back to process name when bundle info dictionary is nil")
    func bundleWrapperNilInfoFallback() async throws {
        try await withIsolatedAppKitState {
            let processInfo = ProcessInfo.processInfo

            let result = FreeApp.applicationName(bundleInfo: nil, processName: processInfo.processName)
            #expect(result == processInfo.processName)
        }
    }

    @MainActor
    @Test("FreeApp launch/start interface and appearance updates are stable")
    func launchStartAndAppearanceLifecycle() async throws {
        try await withIsolatedAppKitState {
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
            try await Task.sleep(nanoseconds: 100000000)
            appState.appearanceMode = .light
            try await Task.sleep(nanoseconds: 100000000)
            appState.appearanceMode = .dark
            try await Task.sleep(nanoseconds: 100000000)
        }
    }

    @MainActor
    @Test("FreeApp status-menu Open App action routes through the wired window activation handler")
    func statusMenuOpenAppActionPath() async throws {
        try await withIsolatedAppKitState {
            let appState = isolatedAppState(name: "statusMenuOpenAppActionPath")
            let app = FreeApp(
                appState: appState,
                appDelegate: AppDelegate(),
                presentMainWindow: { _, _ in }
            )

            app.startInterface(application: NSApplication.shared)
            guard let statusController = app.statusItemController else {
                Issue.record("Expected status item controller")
                return
            }

            let openItem = Mirror(reflecting: statusController).children
                .first(where: { $0.label == "openAppItem" })?
                .value as? NSMenuItem
            #expect(openItem != nil)
            if let openItem, let action = openItem.action {
                _ = NSApp.sendAction(action, to: openItem.target, from: openItem)
            }

            #expect(app.mainWindowController != nil)
            #expect(app.mainWindowController?.window != nil)
        }
    }

    @MainActor
    @Test("FreeApp Open App handler safely no-ops when app instance is released")
    func statusMenuOpenAppActionNoOpAfterAppReleased() async throws {
        try await withIsolatedAppKitState {
            let appState = isolatedAppState(name: "statusMenuOpenAppActionNoOpAfterAppReleased")
            var app: FreeApp? = FreeApp(
                appState: appState,
                appDelegate: AppDelegate(),
                presentMainWindow: { _, _ in }
            )
            app?.startInterface(application: NSApplication.shared)

            guard let statusController = app?.statusItemController else {
                Issue.record("Expected status item controller")
                return
            }
            let openItem = Mirror(reflecting: statusController).children
                .first(where: { $0.label == "openAppItem" })?
                .value as? NSMenuItem
            #expect(openItem != nil)

            weak var weakApp = app
            weakApp = app
            app = nil
            #expect(weakApp == nil)

            if let openItem, let action = openItem.action {
                _ = NSApp.sendAction(action, to: openItem.target, from: openItem)
            }
        }
    }

    @MainActor
    @Test("FreeApp observes calendar provider publisher after interface binding")
    func observesCalendarProviderPublisher() async throws {
        try await withIsolatedAppKitState {
            let suite = "FreeAppTests.observesCalendarProviderPublisher"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)

            let calendar = MockCalendarManager()
            let appState = AppState(defaults: defaults, calendar: calendar, isTesting: true)
            appState.calendarIntegrationEnabled = true

            let app = FreeApp(
                appState: appState,
                appDelegate: AppDelegate(),
                makeMainViewController: { FreeMainViewController(appState: $0) },
                makeStatusItemController: { _ in
                    let controller = FreeStatusItemController(onQuit: {})
                    controller.setStatusButtonProviderForTesting { nil }
                    return controller
                },
                presentMainWindow: { _, _ in }
            )

            app.startInterface(application: NSApplication.shared)
            calendar.events = [
                ExternalEvent(
                    id: "calendar-publisher-observation",
                    title: "Publisher",
                    startDate: Date().addingTimeInterval(600),
                    endDate: Date().addingTimeInterval(1200)
                )
            ]
            try await Task.sleep(nanoseconds: 100000000)

            #expect(app.menuStatusText.contains("Calendar: Next"))
        }
    }

    @MainActor
    @Test("FreeApp didBecomeActive observer triggers monitor permission check without prompt")
    func appDidBecomeActiveChecksPermissions() async throws {
        final class PermissionAutomator: BrowserAutomator {
            var promptValues: [Bool] = []
            func getActiveUrl(for _: NSRunningApplication) -> String? { nil }
            func redirect(app _: NSRunningApplication, to _: String) {}
            func getAllOpenUrls(browsers _: [String]) -> [String] { [] }
            func checkPermissions(prompt: Bool) -> Bool {
                promptValues.append(prompt)
                return true
            }
        }

        try await withIsolatedAppKitState {
            let appState = isolatedAppState(name: "appDidBecomeActiveChecksPermissions")
            let automator = PermissionAutomator()
            let monitor = BrowserMonitor(
                stateSnapshotProvider: { nil },
                onEvent: { _ in },
                server: nil,
                automator: automator,
                startTimer: false
            )
            appState.monitor = monitor
            try await Task.sleep(nanoseconds: 100000000)
            let baselineCallCount = automator.promptValues.count

            let app = FreeApp(
                appState: appState,
                appDelegate: AppDelegate(),
                presentMainWindow: { _, _ in }
            )
            app.startInterface(application: NSApplication.shared)

            NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
            try await Task.sleep(nanoseconds: 30000000)

            #expect(automator.promptValues.count == baselineCallCount + 1)
            #expect(automator.promptValues.last == false)
        }
    }

    @MainActor
    @Test("FreeApp launch callback safely no-ops when app is already released")
    func launchCallbackNoOpsAfterAppRelease() async throws {
        try await withIsolatedAppKitState {
            let appState = isolatedAppState(name: "launchCallbackNoOpsAfterAppRelease")
            let appDelegate = AppDelegate()
            var app: FreeApp? = FreeApp(appState: appState, appDelegate: appDelegate)

            app?.launch(application: NSApplication.shared)
            let callback = appDelegate.onApplicationDidFinishLaunching
            #expect(callback != nil)

            app = nil
            callback?()

            #expect(NSApplication.shared.delegate === appDelegate)
        }
    }

    @MainActor
    @Test("FreeApp quitAction delegates through runtime terminator")
    func quitActionDelegatesToRuntime() async throws {
        try await withIsolatedAppKitState {
            let originalTerminator = FreeAppRuntimeStorage.terminator
            defer { FreeAppRuntimeStorage.terminator = originalTerminator }

            var capturedApplication: NSApplication?
            var capturedSender: Any?
            FreeAppRuntimeStorage.terminator = { app, sender in
                capturedApplication = app
                capturedSender = sender
            }

            let action = FreeApp.quitAction()
            action()

            #expect(capturedApplication === NSApplication.shared)
            #expect(capturedSender == nil)
        }
    }

}
