import Foundation
import AppKit

protocol BrowserAutomator {
    func getActiveUrl(for app: NSRunningApplication) -> String?
    func redirect(app: NSRunningApplication, to url: String)
    func getAllOpenUrls(browsers: [String]) -> [String]
    func checkPermissions(prompt: Bool) -> Bool
}

actor BrowserMonitor {
    enum Event: Sendable {
        case trustedStateChanged(Bool)
    }


    struct StateSnapshot: Sendable {
        let isBlocking: Bool
        let isPaused: Bool
        let blockNewTabs: Bool
        let blockDeveloperHosts: Bool
        let blockLocalNetworkHosts: Bool
        let allowedRules: [String]
    }

    private var timer: (any RepeatingTimer)?
    private let stateSnapshotProvider: @Sendable () async -> StateSnapshot?
    private let onEvent: @Sendable (Event) -> Void
    private let server: LocalServer?
    private let automator: BrowserAutomator
    private let timerScheduler: any RepeatingTimerScheduling
    private let supportedBrowsers: Set<String>
    private let frontmostAppProvider: @Sendable () -> NSRunningApplication?
    private let bundleIdProvider: @Sendable (NSRunningApplication) -> String?
    private let nowProvider: @Sendable () -> Date
    private let monitorInterval: TimeInterval
    private var lastRedirectTime: [String: Date] = [:]
    private var lastEmittedTrusted: Bool?
    private var lastPermissionRecheck: Date?
    private static let permissionRecheckInterval: TimeInterval = 30
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
        stateSnapshotProvider: @escaping @Sendable () async -> StateSnapshot?,
        onEvent: @escaping @Sendable (Event) -> Void,
        server: LocalServer? = LocalServer(),
        automator: BrowserAutomator = DefaultBrowserAutomator(),
        supportedBrowsers: Set<String> = BrowserMonitor.defaultBrowsers,
        frontmostAppProvider: @escaping @Sendable () -> NSRunningApplication? = { NSWorkspace.shared.frontmostApplication },
        bundleIdProvider: @escaping @Sendable (NSRunningApplication) -> String? = { $0.bundleIdentifier },
        nowProvider: @escaping @Sendable () -> Date = { Date() },
        monitorInterval: TimeInterval = 1.5,
        timerScheduler: any RepeatingTimerScheduling = DefaultRepeatingTimerScheduler(),
        startTimer: Bool = true,
        isTesting: Bool = false
    ) {
        self.stateSnapshotProvider = stateSnapshotProvider
        self.onEvent = onEvent
        self.server = server
        self.automator = automator
        self.timerScheduler = timerScheduler
        self.supportedBrowsers = supportedBrowsers
        self.frontmostAppProvider = frontmostAppProvider
        self.bundleIdProvider = bundleIdProvider
        self.nowProvider = nowProvider
        self.monitorInterval = monitorInterval
        let shouldPrompt = !isTesting
        Task {
            await self.checkPermissions(prompt: shouldPrompt)
            await self.server?.start()
            if startTimer {
                await self.startMonitoring()
            }
        }
    }

    isolated deinit {
        timer?.invalidate()
    }

    func checkPermissions(prompt: Bool = false) {
        let trusted = automator.checkPermissions(prompt: prompt)
        guard trusted != lastEmittedTrusted else { return }
        lastEmittedTrusted = trusted
        Task {
            self.onEvent(.trustedStateChanged(trusted))
        }
    }

    func startMonitoring() {
        let repeatingTimer = timerScheduler.scheduledRepeatingTimer(withTimeInterval: monitorInterval) { [weak self] in
            Task { [weak self] in
                await self?.checkActiveTab()
            }
        }
        replaceTimer(with: repeatingTimer)
    }

    func stopMonitoring() {
        replaceTimer(with: nil)
    }

    private var redirectUrlString: String {
        let port = server?.port?.rawValue ?? 10000
        return "http://localhost:\(port)"
    }
    
    private var localServerHostPort: String {
        let port = server?.port?.rawValue ?? 10000
        return "localhost:\(port)"
    }

    func checkActiveTab() async {
        // Re-check permissions on a slow cadence so a revoked grant (Accessibility
        // or Automation) surfaces in the UI instead of blocking failing silently.
        let recheckNow = nowProvider()
        if lastPermissionRecheck.map({ recheckNow.timeIntervalSince($0) >= Self.permissionRecheckInterval }) ?? true {
            lastPermissionRecheck = recheckNow
            checkPermissions()
        }

        guard
            let snapshot = await stateSnapshotProvider(),
            snapshot.isBlocking,
            !snapshot.isPaused,
              let frontApp = frontmostAppProvider(),
              let bundleId = bundleIdProvider(frontApp),
            supportedBrowsers.contains(bundleId)
        else { return }

        let now = nowProvider()

        // Read lastRedirectTime without lock (isolated by actor).
        let lastRedirect = lastRedirectTime[bundleId]
        if let lastRedirect, now.timeIntervalSince(lastRedirect) < 2.0 { return }

        if let currentURL = automator.getActiveUrl(for: frontApp) {
            if currentURL.contains(localServerHostPort) { return }

            if Self.isNewTabLike(currentURL) {
                guard snapshot.blockNewTabs else { return }
                lastRedirectTime[bundleId] = now
                automator.redirect(app: frontApp, to: redirectUrlString)
                return
            }

            if Self.isDeveloperLocalUrl(currentURL) {
                guard snapshot.blockDeveloperHosts else { return }
                lastRedirectTime[bundleId] = now
                automator.redirect(app: frontApp, to: redirectUrlString)
                return
            }

            if Self.isPrivateNetworkUrl(currentURL) {
                guard snapshot.blockLocalNetworkHosts else { return }
                lastRedirectTime[bundleId] = now
                automator.redirect(app: frontApp, to: redirectUrlString)
                return
            }

            let currentPort = server?.port?.rawValue
            if !RuleMatcher.isAllowed(currentURL, rules: snapshot.allowedRules, localPort: currentPort) {
                lastRedirectTime[bundleId] = now
                automator.redirect(app: frontApp, to: redirectUrlString)
            }
        }
    }

    func getAllOpenUrls() -> [String] { automator.getAllOpenUrls(browsers: Array(supportedBrowsers)) }

    private func replaceTimer(with newTimer: (any RepeatingTimer)?) {
        let oldTimer = timer
        timer = newTimer
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
