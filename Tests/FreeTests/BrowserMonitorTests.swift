import Testing
import Foundation
import AppKit
@testable import FreeLogic

class MockBrowserAutomator: BrowserAutomator {
    var activeUrl: String?
    var redirectedUrls: [String] = []
    var getActiveUrlCalls = 0
    var forwardedBrowsers: [String] = []
    var checkedPermissions = false
    var permissionsReturn = true
    
    func getActiveUrl(for app: NSRunningApplication) -> String? {
        getActiveUrlCalls += 1
        return activeUrl
    }

    func redirect(app: NSRunningApplication, to url: String) {
        redirectedUrls.append(url)
    }

    func getAllOpenUrls(browsers: [String]) -> [String] {
        forwardedBrowsers = browsers
        return activeUrl.map { [$0] } ?? []
    }

    func checkPermissions(prompt: Bool) -> Bool {
        checkedPermissions = true
        return permissionsReturn
    }
}

struct BrowserMonitorTests {
    
    private func isolatedAppState(name: String) -> AppState {
        let suite = "BrowserMonitorTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    private func makeMonitor(
        appState: AppState,
        mock: MockBrowserAutomator,
        supportedBrowsers: Set<String> = ["com.google.Chrome"],
        bundleId: String? = "com.google.Chrome",
        nowProvider: @escaping () -> Date = Date.init,
        monitorInterval: TimeInterval = 1.0,
        timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler(),
        startTimer: Bool = false
    ) -> BrowserMonitor {
        BrowserMonitor(
            appState: appState,
            server: nil,
            automator: mock,
            supportedBrowsers: supportedBrowsers,
            frontmostAppProvider: { NSRunningApplication.current },
            bundleIdProvider: { _ in bundleId },
            nowProvider: nowProvider,
            monitorInterval: monitorInterval,
            timerScheduler: timerScheduler,
            startTimer: startTimer
        )
    }

    @Test("BrowserMonitor permission check updates AppState")
    func permissionUpdate() {
        let appState = isolatedAppState(name: "permissionUpdate")
        let mock = MockBrowserAutomator()
        mock.permissionsReturn = false
        
        _ = makeMonitor(appState: appState, mock: mock)
        #expect(mock.checkedPermissions)
    }

    @Test("BrowserMonitor supports default provider wiring without explicit overrides")
    func defaultProviderWiring() {
        let appState = isolatedAppState(name: "defaultProviderWiring")
        let mock = MockBrowserAutomator()

        _ = BrowserMonitor(
            appState: appState,
            server: nil,
            automator: mock,
            startTimer: false
        )

        #expect(mock.checkedPermissions)
    }

    @Test("BrowserMonitor redirects disallowed URL when blocking")
    func redirectsDisallowedUrl() {
        let appState = isolatedAppState(name: "redirectsDisallowedUrl")
        appState.isBlocking = true
        appState.ruleSets = [RuleSet(name: "Allowed", urls: ["google.com"])]

        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://facebook.com"
        let monitor = makeMonitor(appState: appState, mock: mock)

        monitor.checkActiveTab()

        #expect(mock.redirectedUrls == ["http://localhost:10000"])
    }

    @Test("BrowserMonitor does not redirect allowed URL")
    func allowsWhitelistedUrl() {
        let appState = isolatedAppState(name: "allowsWhitelistedUrl")
        appState.isBlocking = true
        appState.ruleSets = [RuleSet(name: "Allowed", urls: ["google.com"])]

        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://docs.google.com/document/123"
        let monitor = makeMonitor(appState: appState, mock: mock)

        monitor.checkActiveTab()

        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor guard clauses prevent URL fetch when paused or unsupported")
    func guardClauses() {
        let appState = isolatedAppState(name: "guardClauses")
        appState.isBlocking = true
        appState.isPaused = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://facebook.com"
        let monitorPaused = makeMonitor(appState: appState, mock: mock)

        monitorPaused.checkActiveTab()
        #expect(mock.getActiveUrlCalls == 0)
        #expect(mock.redirectedUrls.isEmpty)

        appState.isPaused = false
        let monitorUnsupported = makeMonitor(appState: appState, mock: mock, bundleId: "com.unknown.app")
        monitorUnsupported.checkActiveTab()
        #expect(mock.getActiveUrlCalls == 0)
        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor does not fetch URL when blocking is disabled")
    func guardClauseBlockingDisabled() {
        let appState = isolatedAppState(name: "guardClauseBlockingDisabled")
        appState.isBlocking = false

        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://facebook.com"
        let monitor = makeMonitor(appState: appState, mock: mock)

        monitor.checkActiveTab()

        #expect(mock.getActiveUrlCalls == 0)
        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor does not redirect block page itself")
    func localhostBypass() {
        let appState = isolatedAppState(name: "localhostBypass")
        appState.isBlocking = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://localhost:10000"
        let monitor = makeMonitor(appState: appState, mock: mock)

        monitor.checkActiveTab()
        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor throttles repeated redirects per bundle")
    func redirectThrottle() {
        let appState = isolatedAppState(name: "redirectThrottle")
        appState.isBlocking = true

        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://facebook.com"
        let monitor = makeMonitor(
            appState: appState,
            mock: mock,
            nowProvider: { now }
        )

        monitor.checkActiveTab() // redirect #1 at t0
        now = now.addingTimeInterval(1)
        monitor.checkActiveTab() // throttled at t0+1
        now = now.addingTimeInterval(2.1)
        monitor.checkActiveTab() // redirect #2 at t0+3.1

        #expect(mock.redirectedUrls.count == 2)
    }

    @Test("BrowserMonitor ignores missing active URL")
    func missingActiveUrl() {
        let appState = isolatedAppState(name: "missingActiveUrl")
        appState.isBlocking = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = nil
        let monitor = makeMonitor(appState: appState, mock: mock)

        monitor.checkActiveTab()

        #expect(mock.getActiveUrlCalls == 1)
        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor default providers can run on frontmost app path")
    func defaultProvidersExecutionPath() {
        let appState = isolatedAppState(name: "defaultProvidersExecutionPath")
        appState.isBlocking = true

        guard
            let frontApp = NSWorkspace.shared.frontmostApplication,
            let frontBundleId = frontApp.bundleIdentifier
        else {
            return
        }

        let mock = MockBrowserAutomator()
        mock.activeUrl = nil
        let monitor = BrowserMonitor(
            appState: appState,
            server: nil,
            automator: mock,
            supportedBrowsers: [frontBundleId],
            startTimer: false
        )

        monitor.checkActiveTab()

        #expect(mock.getActiveUrlCalls == 1)
    }

    @Test("BrowserMonitor forwards supported browser list to open URL query")
    func openUrlsForwarding() {
        let appState = isolatedAppState(name: "openUrlsForwarding")
        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://example.com"
        let supported: Set<String> = ["com.google.Chrome", "com.apple.Safari"]
        let monitor = makeMonitor(appState: appState, mock: mock, supportedBrowsers: supported)

        let urls = monitor.getAllOpenUrls()

        #expect(urls == ["https://example.com"])
        #expect(Set(mock.forwardedBrowsers) == supported)
    }

    @Test("BrowserMonitor timer loop triggers permission and tab checks")
    func timerLoop() {
        let appState = isolatedAppState(name: "timerLoop")
        appState.isBlocking = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://localhost:10000"
        let monitor = makeMonitor(
            appState: appState,
            mock: mock,
            monitorInterval: 0.01,
            startTimer: true
        )

        mock.checkedPermissions = false
        mock.getActiveUrlCalls = 0

        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        #expect(mock.checkedPermissions)
        #expect(mock.getActiveUrlCalls > 0)
        _ = monitor
    }

    @Test("BrowserMonitor start/stop invalidates replaced timers")
    func startStopInvalidatesTimers() {
        let appState = isolatedAppState(name: "startStopInvalidatesTimers")
        let mock = MockBrowserAutomator()
        let scheduler = MockRepeatingTimerScheduler()
        let monitor = makeMonitor(
            appState: appState,
            mock: mock,
            timerScheduler: scheduler,
            startTimer: true
        )

        #expect(scheduler.timers.count == 1)
        let first = scheduler.timers[0]
        #expect(first.invalidateCallCount == 0)

        monitor.startMonitoring()
        #expect(scheduler.timers.count == 2)
        #expect(first.invalidateCallCount == 1)

        let second = scheduler.timers[1]
        monitor.stopMonitoring()
        #expect(second.invalidateCallCount == 1)
    }

    @Test("BrowserMonitor deinit invalidates active timer")
    func deinitInvalidatesActiveTimer() {
        let appState = isolatedAppState(name: "deinitInvalidatesActiveTimer")
        let mock = MockBrowserAutomator()
        let scheduler = MockRepeatingTimerScheduler()
        var monitor: BrowserMonitor? = makeMonitor(
            appState: appState,
            mock: mock,
            timerScheduler: scheduler,
            startTimer: true
        )
        #expect(monitor != nil)

        #expect(scheduler.timers.count == 1)
        let timer = scheduler.timers[0]
        monitor = nil
        #expect(timer.invalidateCallCount == 1)
    }
}
