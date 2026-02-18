import Foundation
import AppKit
import ApplicationServices

class DefaultBrowserAutomator: BrowserAutomator {
    func checkPermissions(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func redirect(app: NSRunningApplication, to url: String) {
        let name = app.localizedName ?? "Safari", id = app.bundleIdentifier ?? ""
        let script = id == "company.thebrowser.Browser" ? arcRedirect(url) : (id == "com.apple.Safari" ? safariRedirect(url) : chromRedirect(name, url))
        execute(script)
    }

    func getActiveUrl(for app: NSRunningApplication) -> String? {
        let id = app.bundleIdentifier ?? "", name = app.localizedName ?? "Safari"
        if id == "company.thebrowser.Browser" {
            if let url = execute("tell application \"Arc\" to return URL of active tab of front window"), !url.isEmpty { return url }
            return getArcAccessibilityURL(pid: app.processIdentifier)
        }
        let cmd = id == "com.apple.Safari" ? "tell application \"Safari\" to return URL of current tab of front window" : "tell application \"\(name)\" to return URL of active tab of front window"
        return execute(cmd)
    }

    func getAllOpenUrls(browsers: [String]) -> [String] {
        var urls = Set<String>()
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier, browsers.contains(id) else { continue }
            let name = app.localizedName ?? ""
            let appName = id == "com.apple.Safari" ? "Safari" : (id == "company.thebrowser.Browser" ? "Arc" : name)
            let script = "set o to \"\"\ntell application \"\(appName)\"\nrepeat with w in windows\nrepeat with t in tabs of w\nset o to o & URL of t & \"\n\"\nend repeat\nend repeat\nend tell\nreturn o"
            execute(script)?.components(separatedBy: "\n").forEach {
                let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty && !t.contains("localhost:10000") { urls.insert(t) }
            }
        }
        return Array(urls).sorted()
    }

    @discardableResult
    private func execute(_ source: String) -> String? {
        NSAppleScript(source: source)?.executeAndReturnError(nil).stringValue
    }

    private func arcRedirect(_ url: String) -> String {
        "tell application \"Arc\"\nactivate\nif (count of windows) > 0 then\ntry\nset URL of active tab of front window to \"\(url)\"\non error\ntell application \"System Events\" to tell process \"Arc\"\nkeystroke \"l\" using {command down}\ndelay 0.1\nkeystroke \"\(url)\"\nkey code 36\nend tell\nend try\nelse\nopen location \"\(url)\"\nend if\nend tell"
    }
    private func safariRedirect(_ url: String) -> String { "tell application \"Safari\" to if (count of windows) > 0 then set URL of current tab of front window to \"\(url)\"" }
    private func chromRedirect(_ name: String, _ url: String) -> String { "tell application \"\(name)\" to if (count of windows) > 0 then set URL of active tab of front window to \"\(url)\"" }

    private func getArcAccessibilityURL(pid: pid_t) -> String? {
        let ax = AXUIElementCreateApplication(pid)
        var win: CFTypeRef?
        if AXUIElementCopyAttributeValue(ax, kAXFocusedWindowAttribute as CFString, &win) == .success, let url = findURL(win as! AXUIElement) { return url }
        if AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &win) == .success, let list = win as? [AXUIElement], let first = list.first { return findURL(first) }
        return nil
    }

    private func findURL(_ el: AXUIElement, depth: Int = 0) -> String? {
        if depth > 15 { return nil }
        var r: CFTypeRef?, t: CFTypeRef?, v: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &r)
        AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &t)
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v)
        let rs = r as? String ?? "", ts = t as? String ?? "", vs = (v as? String ?? "").trimmingCharacters(in: .whitespaces)
        if ["AXTextField", "AXStaticText", "AXComboBox"].contains(rs) && !vs.isEmpty {
            if vs.lowercased().hasPrefix("http") { return vs }
            if vs.contains(".") && !vs.contains(" ") && vs.count > 3 { return "https://" + vs }
        }
        if depth == 0 && (ts.hasPrefix("http") || (ts.contains(".") && !ts.contains(" "))) { return ts.hasPrefix("http") ? ts : "https://" + ts }
        var kids: CFTypeRef?
        if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &kids) == .success, let list = kids as? [AXUIElement] {
            for k in list { if let found = findURL(k, depth: depth + 1) { return found } }
        }
        return nil
    }
}
