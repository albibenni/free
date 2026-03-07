import Foundation
import AppKit

protocol BrowserAutomator {
    func getActiveUrl(for app: NSRunningApplication) -> String?
    func redirect(app: NSRunningApplication, to url: String)
    func getAllOpenUrls(browsers: [String]) -> [String]
    func checkPermissions(prompt: Bool) -> Bool
}

class BrowserMonitor {
    private enum TestRuntime {
        static func isActive() -> Bool {
            let environment = ProcessInfo.processInfo.environment
            if environment["XCTestConfigurationFilePath"] != nil { return true }
            if environment["XCTestBundlePath"] != nil { return true }
            if environment["SWIFT_TESTING_ENABLE_EXPERIMENTAL_FEATURES"] != nil { return true }
            if environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] != nil { return true }
            return NSClassFromString("XCTestCase") != nil
        }
    }

    struct StateSnapshot {
        let isBlocking: Bool
        let isPaused: Bool
        let blockNewTabs: Bool
        let blockDeveloperHosts: Bool
        let blockLocalNetworkHosts: Bool
        let allowedRules: [String]
    }

    private var timer: (any RepeatingTimer)?
    private let timerLock = NSLock()
    private let stateSnapshotProvider: () -> StateSnapshot?
    private let setTrustedState: (Bool) -> Void
    private let server: LocalServer?
    private let automator: BrowserAutomator
    private let timerScheduler: any RepeatingTimerScheduling
    private let supportedBrowsers: Set<String>
    private let frontmostAppProvider: () -> NSRunningApplication?
    private let bundleIdProvider: (NSRunningApplication) -> String?
    private let nowProvider: () -> Date
    private let monitorInterval: TimeInterval
    private var lastRedirectTime: [String: Date] = [:]
    private static let defaultBrowsers: Set<String> = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "company.thebrowser.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
    ]
    private static let newTabTokens: Set<String> = [
        "new tab",
        "start page",
        "startpage",
        "about:blank",
        "about:newtab",
        "chrome://newtab",
        "brave://newtab",
        "edge://newtab",
        "arc://newtab",
        "vivaldi://newtab",
        "opera://startpage",
        "favorites://",
        "topsites://",
    ]

    init(
        stateSnapshotProvider: @escaping () -> StateSnapshot?,
        setTrustedState: @escaping (Bool) -> Void,
        server: LocalServer? = LocalServer(),
        automator: BrowserAutomator = DefaultBrowserAutomator(),
        supportedBrowsers: Set<String> = BrowserMonitor.defaultBrowsers,
        frontmostAppProvider: @escaping () -> NSRunningApplication? = { NSWorkspace.shared.frontmostApplication },
        bundleIdProvider: @escaping (NSRunningApplication) -> String? = { $0.bundleIdentifier },
        nowProvider: @escaping () -> Date = Date.init,
        monitorInterval: TimeInterval = 1.0,
        timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler(),
        startTimer: Bool = true
    ) {
        self.stateSnapshotProvider = stateSnapshotProvider
        self.setTrustedState = setTrustedState
        self.server = server
        self.automator = automator
        self.timerScheduler = timerScheduler
        self.supportedBrowsers = supportedBrowsers
        self.frontmostAppProvider = frontmostAppProvider
        self.bundleIdProvider = bundleIdProvider
        self.nowProvider = nowProvider
        self.monitorInterval = monitorInterval
        checkPermissions(prompt: !TestRuntime.isActive())
        server?.start()
        if startTimer {
            startMonitoring()
        }
    }

    deinit {
        stopMonitoring()
    }

    func checkPermissions(prompt: Bool = false) {
        let trusted = automator.checkPermissions(prompt: prompt)
        DispatchQueue.main.async { [weak self] in
            self?.setTrustedState(trusted)
        }
    }

    func startMonitoring() {
        let repeatingTimer = timerScheduler.scheduledRepeatingTimer(withTimeInterval: monitorInterval) { [weak self] in
            self?.checkPermissions(prompt: false)
            self?.checkActiveTab()
        }
        replaceTimer(with: repeatingTimer)
    }

    func stopMonitoring() {
        replaceTimer(with: nil)
    }

    func checkActiveTab() {
        guard
            let snapshot = stateSnapshotProvider(),
            snapshot.isBlocking,
            !snapshot.isPaused,
              let frontApp = frontmostAppProvider(),
              let bundleId = bundleIdProvider(frontApp),
            supportedBrowsers.contains(bundleId)
        else { return }

        let now = nowProvider()
        if let lastRedirect = lastRedirectTime[bundleId], now.timeIntervalSince(lastRedirect) < 2.0 { return }

        if let currentURL = automator.getActiveUrl(for: frontApp) {
            if currentURL.contains("localhost:10000") { return }

            if Self.isNewTabLike(currentURL) {
                guard snapshot.blockNewTabs else { return }
                lastRedirectTime[bundleId] = now
                automator.redirect(app: frontApp, to: "http://localhost:10000")
                return
            }

            if Self.isDeveloperLocalUrl(currentURL) {
                guard snapshot.blockDeveloperHosts else { return }
                lastRedirectTime[bundleId] = now
                automator.redirect(app: frontApp, to: "http://localhost:10000")
                return
            }

            if Self.isPrivateNetworkUrl(currentURL) {
                guard snapshot.blockLocalNetworkHosts else { return }
                lastRedirectTime[bundleId] = now
                automator.redirect(app: frontApp, to: "http://localhost:10000")
                return
            }

            if !RuleMatcher.isAllowed(currentURL, rules: snapshot.allowedRules) {
                lastRedirectTime[bundleId] = now
                automator.redirect(app: frontApp, to: "http://localhost:10000")
            }
        }
    }

    func getAllOpenUrls() -> [String] { automator.getAllOpenUrls(browsers: Array(supportedBrowsers)) }

    private func replaceTimer(with newTimer: (any RepeatingTimer)?) {
        timerLock.lock()
        let oldTimer = timer
        timer = newTimer
        timerLock.unlock()
        oldTimer?.invalidate()
    }

    private static func isNewTabLike(_ rawUrl: String) -> Bool {
        let cleaned = rawUrl.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if newTabTokens.contains(cleaned) { return true }
        if cleaned.hasPrefix("chrome://newtab/")
            || cleaned.hasPrefix("brave://newtab/")
            || cleaned.hasPrefix("edge://newtab/")
            || cleaned.hasPrefix("arc://newtab/")
            || cleaned.hasPrefix("vivaldi://newtab/")
        {
            return true
        }
        return false
    }

    private static func isDeveloperLocalUrl(_ rawUrl: String) -> Bool {
        guard let host = host(from: rawUrl) else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "0.0.0.0"
    }

    private static func isPrivateNetworkUrl(_ rawUrl: String) -> Bool {
        guard let host = host(from: rawUrl) else { return false }
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return false }
        let octets = parts.compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ 0...255 ~= $0 }) else { return false }

        let first = octets[0]
        let second = octets[1]
        if first == 10 { return true }
        if first == 192 && second == 168 { return true }
        if first == 172 && (16...31).contains(second) { return true }
        return false
    }

    private static func host(from rawUrl: String) -> String? {
        let cleaned = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return nil }

        let direct = URLComponents(string: cleaned)
        let withHTTP = URLComponents(string: "http://" + cleaned)
        return (direct?.host ?? withHTTP?.host)?.lowercased()
    }
}
