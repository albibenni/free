import Foundation
import AppKit

protocol BrowserAutomator {
    func getActiveUrl(for app: NSRunningApplication) -> String?
    func redirect(app: NSRunningApplication, to url: String)
    func getAllOpenUrls(browsers: [String]) -> [String]
    func checkPermissions(prompt: Bool) -> Bool
}

class BrowserMonitor {
    private var timer: (any RepeatingTimer)?
    private let timerLock = NSLock()
    private weak var appState: AppState?
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

    init(
        appState: AppState,
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
        self.appState = appState
        self.server = server
        self.automator = automator
        self.timerScheduler = timerScheduler
        self.supportedBrowsers = supportedBrowsers
        self.frontmostAppProvider = frontmostAppProvider
        self.bundleIdProvider = bundleIdProvider
        self.nowProvider = nowProvider
        self.monitorInterval = monitorInterval
        checkPermissions(prompt: true)
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
            self?.appState?.isTrusted = trusted
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
        guard let appState = appState, appState.isBlocking, !appState.isPaused,
              let frontApp = frontmostAppProvider(),
              let bundleId = bundleIdProvider(frontApp),
              supportedBrowsers.contains(bundleId) else { return }

        let now = nowProvider()
        if let lastRedirect = lastRedirectTime[bundleId], now.timeIntervalSince(lastRedirect) < 2.0 { return }

        if let currentURL = automator.getActiveUrl(for: frontApp) {
            if currentURL.contains("localhost:10000") { return }
            if !RuleMatcher.isAllowed(currentURL, rules: appState.allowedRules) {
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
}
