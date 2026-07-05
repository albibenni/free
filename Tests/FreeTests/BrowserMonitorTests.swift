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
    var prompts: [Bool] = []
    
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
        prompts.append(prompt)
        return permissionsReturn
    }
}

@Suite(.serialized)
@MainActor
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
        nowProvider: @escaping @Sendable () -> Date = { Date() },
        monitorInterval: TimeInterval = 1.0,
        timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler(),
        startTimer: Bool = false,
        testRuntimeActive: Bool? = nil
    ) -> BrowserMonitor {
        BrowserMonitor(
            stateSnapshotProvider: { @MainActor in
                BrowserMonitor.StateSnapshot(
                    isBlocking: appState.isBlocking,
                    isPaused: appState.isPaused,
                    blockNewTabs: appState.blockNewTabs,
                    blockDeveloperHosts: appState.blockDeveloperHosts,
                    blockLocalNetworkHosts: appState.blockLocalNetworkHosts,
                    allowedRules: appState.allowedRules
                )
            },
            onEvent: { event in
                Task { @MainActor in
                    if case .trustedStateChanged(let trusted) = event { appState.isTrusted = trusted }
                }
            },
            server: nil,
            automator: mock,
            supportedBrowsers: supportedBrowsers,
            frontmostAppProvider: { NSRunningApplication.current },
            bundleIdProvider: { _ in bundleId },
            nowProvider: nowProvider,
            monitorInterval: monitorInterval,
            timerScheduler: timerScheduler,
            startTimer: startTimer,
            isTesting: testRuntimeActive ?? true
        )
    }

    @Test("BrowserMonitor permission check updates AppState")
    func permissionUpdate() async {
        let appState = isolatedAppState(name: "permissionUpdate")
        let mock = MockBrowserAutomator()
        mock.permissionsReturn = false
        
        _ = makeMonitor(appState: appState, mock: mock)
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(mock.checkedPermissions)
    }

    @Test("BrowserMonitor supports default provider wiring without explicit overrides")
    func defaultProviderWiring() async {
        let appState = isolatedAppState(name: "defaultProviderWiring")
        let mock = MockBrowserAutomator()

        _ = BrowserMonitor(
            stateSnapshotProvider: { @MainActor in
                BrowserMonitor.StateSnapshot(
                    isBlocking: appState.isBlocking,
                    isPaused: appState.isPaused,
                    blockNewTabs: appState.blockNewTabs,
                    blockDeveloperHosts: appState.blockDeveloperHosts,
                    blockLocalNetworkHosts: appState.blockLocalNetworkHosts,
                    allowedRules: appState.allowedRules
                )
            },
            onEvent: { event in
                Task { @MainActor in
                    if case .trustedStateChanged(let trusted) = event { appState.isTrusted = trusted }
                }
            },
            server: nil,
            automator: mock,
            startTimer: false
        )
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(mock.checkedPermissions)
    }

    @Test("BrowserMonitor redirects disallowed URL when blocking")
    func redirectsDisallowedUrl() async {
        let appState = isolatedAppState(name: "redirectsDisallowedUrl")
        appState.isBlocking = true
        appState.ruleSets = [RuleSet(name: "Allowed", urls: ["google.com"])]

        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://facebook.com"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls == ["http://localhost:10000"])
    }

    @Test("BrowserMonitor does not redirect allowed URL")
    func allowsWhitelistedUrl() async {
        let appState = isolatedAppState(name: "allowsWhitelistedUrl")
        appState.isBlocking = true
        appState.ruleSets = [RuleSet(name: "Allowed", urls: ["google.com"])]

        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://docs.google.com/document/123"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor guard clauses prevent URL fetch when paused or unsupported")
    func guardClauses() async {
        let appState = isolatedAppState(name: "guardClauses")
        appState.isBlocking = true
        appState.isPaused = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://facebook.com"
        let monitorPaused = makeMonitor(appState: appState, mock: mock)

        await monitorPaused.checkActiveTab()
        #expect(mock.getActiveUrlCalls == 0)
        #expect(mock.redirectedUrls.isEmpty)

        appState.isPaused = false
        let monitorUnsupported = makeMonitor(appState: appState, mock: mock, bundleId: "com.unknown.app")
        await monitorUnsupported.checkActiveTab()
        #expect(mock.getActiveUrlCalls == 0)
        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor does not fetch URL when blocking is disabled")
    func guardClauseBlockingDisabled() async {
        let appState = isolatedAppState(name: "guardClauseBlockingDisabled")
        appState.isBlocking = false

        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://facebook.com"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.getActiveUrlCalls == 0)
        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor does not redirect block page itself")
    func localhostBypass() async {
        let appState = isolatedAppState(name: "localhostBypass")
        appState.isBlocking = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://localhost:10000"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()
        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor allows new-tab pages by default")
    func allowsNewTabByDefault() async {
        let appState = isolatedAppState(name: "allowsNewTabByDefault")
        appState.isBlocking = true
        #expect(appState.blockNewTabs == false)

        let mock = MockBrowserAutomator()
        mock.activeUrl = "chrome://newtab/"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor can block new-tab pages when enabled")
    func blocksNewTabWhenEnabled() async {
        let appState = isolatedAppState(name: "blocksNewTabWhenEnabled")
        appState.isBlocking = true
        appState.blockNewTabs = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "chrome://newtab/"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls == ["http://localhost:10000"])
    }

    @Test("BrowserMonitor allows localhost and loopback URLs by default")
    func allowsDeveloperHostsByDefault() async {
        let appState = isolatedAppState(name: "allowsDeveloperHostsByDefault")
        appState.isBlocking = true
        #expect(appState.blockDeveloperHosts == false)

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://localhost:3000"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor can block localhost and loopback URLs when enabled")
    func blocksDeveloperHostsWhenEnabled() async {
        let appState = isolatedAppState(name: "blocksDeveloperHostsWhenEnabled")
        appState.isBlocking = true
        appState.blockDeveloperHosts = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://127.0.0.1:5173"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls == ["http://localhost:10000"])
    }

    @Test("BrowserMonitor allows private-network router URLs by default")
    func allowsPrivateNetworkUrlsByDefault() async {
        let appState = isolatedAppState(name: "allowsPrivateNetworkUrlsByDefault")
        appState.isBlocking = true
        #expect(appState.blockLocalNetworkHosts == false)

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://192.168.0.1/"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor can block private-network router URLs when enabled")
    func blocksPrivateNetworkUrlsWhenEnabled() async {
        let appState = isolatedAppState(name: "blocksPrivateNetworkUrlsWhenEnabled")
        appState.isBlocking = true
        appState.blockLocalNetworkHosts = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://192.168.0.1/"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls == ["http://localhost:10000"])
    }

    @Test("BrowserMonitor blocks explicit new-tab token URLs when enabled")
    func blocksNewTabTokenWhenEnabled() async {
        let appState = isolatedAppState(name: "blocksNewTabTokenWhenEnabled")
        appState.isBlocking = true
        appState.blockNewTabs = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "about:newtab"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls == ["http://localhost:10000"])
    }

    @Test("BrowserMonitor blocks schemeless localhost URL when developer-host blocking is enabled")
    func blocksSchemelessLocalhostWhenEnabled() async {
        let appState = isolatedAppState(name: "blocksSchemelessLocalhostWhenEnabled")
        appState.isBlocking = true
        appState.blockDeveloperHosts = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "localhost:3000"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls == ["http://localhost:10000"])
    }

    @Test("BrowserMonitor does not redirect when active URL is empty")
    func emptyActiveUrlNoRedirect() async {
        let appState = isolatedAppState(name: "emptyActiveUrlNoRedirect")
        appState.isBlocking = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "   "
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor blocks 10.x private-network hosts when enabled")
    func blocksTenRangeWhenEnabled() async {
        let appState = isolatedAppState(name: "blocksTenRangeWhenEnabled")
        appState.isBlocking = true
        appState.blockLocalNetworkHosts = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://10.0.0.5:8080"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls == ["http://localhost:10000"])
    }

    @Test("BrowserMonitor blocks 172.16-31 private-network hosts when enabled")
    func blocksOneSevenTwoPrivateRangeWhenEnabled() async {
        let appState = isolatedAppState(name: "blocksOneSevenTwoPrivateRangeWhenEnabled")
        appState.isBlocking = true
        appState.blockLocalNetworkHosts = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://172.20.10.2/"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls == ["http://localhost:10000"])
    }

    @Test("BrowserMonitor allows non-private IP hosts when private-network blocking is enabled")
    func allowsPublicIpWhenPrivateBlockingEnabled() async {
        let appState = isolatedAppState(name: "allowsPublicIpWhenPrivateBlockingEnabled")
        appState.isBlocking = true
        appState.blockLocalNetworkHosts = true
        appState.ruleSets = [RuleSet(name: "All", urls: ["*"])]
        appState.activeRuleSetId = appState.ruleSets.first?.id

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://203.0.113.10:8080"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor treats out-of-range IP octets as non-private hosts")
    func outOfRangeOctetFallsBackToNonPrivate() async {
        let appState = isolatedAppState(name: "outOfRangeOctetFallsBackToNonPrivate")
        appState.isBlocking = true
        appState.blockLocalNetworkHosts = true
        appState.ruleSets = [RuleSet(name: "All", urls: ["*"])]
        appState.activeRuleSetId = appState.ruleSets.first?.id

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://300.168.0.1/"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor throttles repeated redirects per bundle")
    func redirectThrottle() async {
        let appState = isolatedAppState(name: "redirectThrottle")
        appState.isBlocking = true

        final class DateRef: @unchecked Sendable { var value: Date; init(_ v: Date) { value = v } }
        let now = DateRef(Date(timeIntervalSince1970: 1_700_000_000))
        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://facebook.com"
        let monitor = makeMonitor(
            appState: appState,
            mock: mock,
            nowProvider: { now.value }
        )

        await monitor.checkActiveTab() // redirect #1 at t0
        now.value = now.value.addingTimeInterval(1)
        await monitor.checkActiveTab() // throttled at t0+1
        now.value = now.value.addingTimeInterval(2.1)
        await monitor.checkActiveTab() // redirect #2 at t0+3.1

        #expect(mock.redirectedUrls.count == 2)
    }

    @Test("BrowserMonitor ignores missing active URL")
    func missingActiveUrl() async {
        let appState = isolatedAppState(name: "missingActiveUrl")
        appState.isBlocking = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = nil
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.getActiveUrlCalls == 1)
        #expect(mock.redirectedUrls.isEmpty)
    }

    @Test("BrowserMonitor default providers can run on frontmost app path")
    func defaultProvidersExecutionPath() async {
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
            stateSnapshotProvider: { @MainActor in
                BrowserMonitor.StateSnapshot(
                    isBlocking: appState.isBlocking,
                    isPaused: appState.isPaused,
                    blockNewTabs: appState.blockNewTabs,
                    blockDeveloperHosts: appState.blockDeveloperHosts,
                    blockLocalNetworkHosts: appState.blockLocalNetworkHosts,
                    allowedRules: appState.allowedRules
                )
            },
            onEvent: { event in
                Task { @MainActor in
                    if case .trustedStateChanged(let trusted) = event { appState.isTrusted = trusted }
                }
            },
            server: nil,
            automator: mock,
            supportedBrowsers: [frontBundleId],
            startTimer: false
        )

        await monitor.checkActiveTab()

        #expect(mock.getActiveUrlCalls == 1)
    }

    @Test("BrowserMonitor forwards supported browser list to open URL query")
    func openUrlsForwarding() async {
        let appState = isolatedAppState(name: "openUrlsForwarding")
        let mock = MockBrowserAutomator()
        mock.activeUrl = "https://example.com"
        let supported: Set<String> = ["com.google.Chrome", "com.apple.Safari"]
        let monitor = makeMonitor(appState: appState, mock: mock, supportedBrowsers: supported)

        let urls = await monitor.getAllOpenUrls()

        #expect(urls == ["https://example.com"])
        #expect(Set(mock.forwardedBrowsers) == supported)
    }

    @Test("BrowserMonitor timer loop triggers tab checks and rechecks permissions at most once per cadence")
    func timerLoop() async {
        let appState = isolatedAppState(name: "timerLoop")
        appState.isBlocking = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "http://localhost:10000"
        let scheduler = MockRepeatingTimerScheduler()
        let monitor = makeMonitor(
            appState: appState,
            mock: mock,
            monitorInterval: 0.01,
            timerScheduler: scheduler,
            startTimer: true
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        mock.checkedPermissions = false
        mock.getActiveUrlCalls = 0

        #expect(scheduler.intervals == [0.01])
        #expect(scheduler.handlers.count == 1)

        scheduler.fire(at: 0)
        try? await Task.sleep(nanoseconds: 50_000_000)

        // The first tick re-checks permissions so a revoked grant surfaces in the UI.
        #expect(mock.checkedPermissions == true)
        #expect(mock.getActiveUrlCalls > 0)

        // Within the recheck cadence, subsequent ticks must not poll again.
        mock.checkedPermissions = false
        scheduler.fire(at: 0)
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(mock.checkedPermissions == false)
        _ = monitor
    }

    @Test("BrowserMonitor start/stop invalidates replaced timers")
    func startStopInvalidatesTimers() async {
        let appState = isolatedAppState(name: "startStopInvalidatesTimers")
        let mock = MockBrowserAutomator()
        let scheduler = MockRepeatingTimerScheduler()
        let monitor = makeMonitor(
            appState: appState,
            mock: mock,
            timerScheduler: scheduler,
            startTimer: true
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(scheduler.timers.count == 1)
        let first = scheduler.timers[0]
        #expect(first.invalidateCallCount == 0)

        await monitor.startMonitoring()
        #expect(scheduler.timers.count == 2)
        #expect(first.invalidateCallCount == 1)

        let second = scheduler.timers[1]
        await monitor.stopMonitoring()
        #expect(second.invalidateCallCount == 1)
    }

    @Test("BrowserMonitor deinit invalidates active timer")
    func deinitInvalidatesActiveTimer() async {
        let appState = isolatedAppState(name: "deinitInvalidatesActiveTimer")
        let mock = MockBrowserAutomator()
        let scheduler = MockRepeatingTimerScheduler()
        weak var weakMonitor: BrowserMonitor?

        do {
            let monitor = makeMonitor(
                appState: appState,
                mock: mock,
                timerScheduler: scheduler,
                startTimer: true
            )
            try? await Task.sleep(nanoseconds: 50_000_000)
            weakMonitor = monitor
            #expect(scheduler.timers.count == 1)
        }

        #expect(weakMonitor == nil)
        let timer = scheduler.timers[0]

        let timeout = Date().addingTimeInterval(0.25)
        while timer.invalidateCallCount < 1, Date() < timeout {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(timer.invalidateCallCount == 1)
    }

    @Test("BrowserMonitor TestRuntime environment probes cover all early-return branches")
    func testRuntimeEnvironmentCoverage() async {
        let appState = isolatedAppState(name: "testRuntimeEnvironmentCoverage")
        let mock = MockBrowserAutomator()

        _ = makeMonitor(appState: appState, mock: mock, startTimer: false, testRuntimeActive: false)
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(mock.prompts.isEmpty == false)
    }

    @Test("BrowserMonitor blocks prefixed new-tab URLs via hasPrefix branch")
    func blocksPrefixedNewTabWhenEnabled() async {
        let appState = isolatedAppState(name: "blocksPrefixedNewTabWhenEnabled")
        appState.isBlocking = true
        appState.blockNewTabs = true

        let mock = MockBrowserAutomator()
        mock.activeUrl = "chrome://newtab/page"
        let monitor = makeMonitor(appState: appState, mock: mock)

        await monitor.checkActiveTab()

        #expect(mock.redirectedUrls == ["http://localhost:10000"])
    }
}
