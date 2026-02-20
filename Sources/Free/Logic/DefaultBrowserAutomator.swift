import Foundation
import AppKit

struct BrowserAutomationApplication {
    let bundleIdentifier: String?
    let localizedName: String?
    let processIdentifier: pid_t
}

struct DefaultBrowserAutomatorRuntime {
    var checkPermissions: (_ prompt: Bool) -> Bool
    var executeAppleScript: (_ source: String) -> String?
    var runningApplications: () -> [BrowserAutomationApplication]
    var arcAccessibilityURL: (_ pid: pid_t) -> String?
}

class DefaultBrowserAutomator: BrowserAutomator {
    static let arcBundleIdentifier = "company.thebrowser.Browser"
    static let safariBundleIdentifier = "com.apple.Safari"
    static let blockPageHost = "localhost:10000"
    static let arcActiveURLScript = "tell application \"Arc\" to return URL of active tab of front window"

    private let runtime: DefaultBrowserAutomatorRuntime

    init(runtime: DefaultBrowserAutomatorRuntime = .live()) {
        self.runtime = runtime
    }

    func checkPermissions(prompt: Bool) -> Bool {
        runtime.checkPermissions(prompt)
    }

    func redirect(app: NSRunningApplication, to url: String) {
        redirect(bundleIdentifier: app.bundleIdentifier, localizedName: app.localizedName, to: url)
    }

    func redirect(bundleIdentifier: String?, localizedName: String?, to url: String) {
        let bundleId = bundleIdentifier ?? ""
        let appName = localizedName ?? "Safari"
        let script = redirectScript(bundleIdentifier: bundleId, appName: appName, url: url)
        _ = runtime.executeAppleScript(script)
    }

    func getActiveUrl(for app: NSRunningApplication) -> String? {
        getActiveUrl(bundleIdentifier: app.bundleIdentifier, localizedName: app.localizedName, pid: app.processIdentifier)
    }

    func getActiveUrl(bundleIdentifier: String?, localizedName: String?, pid: pid_t) -> String? {
        let bundleId = bundleIdentifier ?? ""
        let appName = localizedName ?? "Safari"

        if bundleId == Self.arcBundleIdentifier {
            if let url = runtime.executeAppleScript(Self.arcActiveURLScript), !url.isEmpty {
                return url
            }
            return runtime.arcAccessibilityURL(pid)
        }

        let command = activeURLScript(bundleIdentifier: bundleId, appName: appName)
        return runtime.executeAppleScript(command)
    }

    func getAllOpenUrls(browsers: [String]) -> [String] {
        getAllOpenUrls(applications: runtime.runningApplications(), browsers: Set(browsers))
    }

    func getAllOpenUrls(applications: [BrowserAutomationApplication], browsers: Set<String>) -> [String] {
        var urls = Set<String>()

        for app in applications {
            guard let bundleId = app.bundleIdentifier, browsers.contains(bundleId) else { continue }
            let appName = scriptAppName(bundleIdentifier: bundleId, localizedName: app.localizedName ?? "")
            let script = allTabsScript(appName: appName)
            let parsed = parseScriptOutput(runtime.executeAppleScript(script))
            for parsedURL in parsed {
                urls.insert(parsedURL)
            }
        }

        return Array(urls).sorted()
    }

    func redirectScript(bundleIdentifier: String, appName: String, url: String) -> String {
        if bundleIdentifier == Self.arcBundleIdentifier { return arcRedirect(url) }
        if bundleIdentifier == Self.safariBundleIdentifier { return safariRedirect(url) }
        return chromRedirect(appName, url)
    }

    func activeURLScript(bundleIdentifier: String, appName: String) -> String {
        if bundleIdentifier == Self.safariBundleIdentifier {
            return "tell application \"Safari\" to return URL of current tab of front window"
        }
        return "tell application \"\(appName)\" to return URL of active tab of front window"
    }

    func scriptAppName(bundleIdentifier: String, localizedName: String) -> String {
        if bundleIdentifier == Self.safariBundleIdentifier { return "Safari" }
        if bundleIdentifier == Self.arcBundleIdentifier { return "Arc" }
        return localizedName
    }

    func allTabsScript(appName: String) -> String {
        "set o to \"\"\ntell application \"\(appName)\"\nrepeat with w in windows\nrepeat with t in tabs of w\nset o to o & URL of t & \"\n\"\nend repeat\nend repeat\nend tell\nreturn o"
    }

    func parseScriptOutput(_ output: String?) -> [String] {
        guard let output else { return [] }
        return output.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            guard !trimmed.contains(Self.blockPageHost) else { return nil }
            return trimmed
        }
    }

    func arcRedirect(_ url: String) -> String {
        "tell application \"Arc\"\nactivate\nif (count of windows) > 0 then\ntry\nset URL of active tab of front window to \"\(url)\"\non error\ntell application \"System Events\" to tell process \"Arc\"\nkeystroke \"l\" using {command down}\ndelay 0.1\nkeystroke \"\(url)\"\nkey code 36\nend tell\nend try\nelse\nopen location \"\(url)\"\nend if\nend tell"
    }

    func safariRedirect(_ url: String) -> String {
        "tell application \"Safari\" to if (count of windows) > 0 then set URL of current tab of front window to \"\(url)\""
    }

    func chromRedirect(_ appName: String, _ url: String) -> String {
        "tell application \"\(appName)\" to if (count of windows) > 0 then set URL of active tab of front window to \"\(url)\""
    }
}
