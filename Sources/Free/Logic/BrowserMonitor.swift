import Foundation
import AppKit
import ApplicationServices

protocol BrowserAutomator {
    func getActiveUrl(for app: NSRunningApplication) -> String?
    func redirect(app: NSRunningApplication, to url: String)
    func getAllOpenUrls(browsers: [String]) -> [String]
    func checkPermissions(prompt: Bool) -> Bool
}

class DefaultBrowserAutomator: BrowserAutomator {
    func checkPermissions(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func redirect(app: NSRunningApplication, to url: String) {
        let scriptSource: String
        let appName = app.localizedName ?? "Safari"
        let bundleId = app.bundleIdentifier ?? ""
        
        if bundleId == "company.thebrowser.Browser" {
            scriptSource = """
            tell application "Arc"
                activate
                if (count of windows) > 0 then
                    try
                        set URL of active tab of front window to "\(url)"
                    on error
                        try
                            tell application "System Events"
                                tell process "Arc"
                                    keystroke "l" using {command down}
                                    delay 0.1
                                    keystroke "\(url)"
                                    key code 36
                                end tell
                            end tell
                        on error
                        end try
                    end try
                else
                    open location "\(url)"
                end if
            end tell
            """
        } else if bundleId == "com.apple.Safari" {
             scriptSource = """
            tell application "Safari"
                if (count of windows) > 0 then
                    set URL of current tab of front window to "\(url)"
                end if
            end tell
            """
        } else {
            scriptSource = """
            tell application "\(appName)"
                if (count of windows) > 0 then
                    set URL of active tab of front window to "\(url)"
                end if
            end tell
            """
        }
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            scriptObject.executeAndReturnError(&error)
        }
    }

    func getActiveUrl(for app: NSRunningApplication) -> String? {
        let bundleId = app.bundleIdentifier ?? ""
        let appName = app.localizedName ?? "Safari"
        
        if bundleId == "company.thebrowser.Browser" {
            let scriptSource = """
            tell application "Arc"
                try
                    if (count of windows) > 0 then
                        return URL of active tab of front window
                    end if
                on error
                    return ""
                end try
            end tell
            """
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptSource) {
                let output = scriptObject.executeAndReturnError(&error)
                let url = output.stringValue ?? ""
                if !url.isEmpty { return url }
            }
            return getArcURL(pid: app.processIdentifier)
        }

        var scriptSource = ""
        if bundleId == "com.apple.Safari" {
            scriptSource = """
            tell application "Safari"
                if (count of windows) > 0 then
                    get URL of current tab of front window
                end if
            end tell
            """
        } else {
            scriptSource = """
            tell application "\(appName)"
                if (count of windows) > 0 then
                    get URL of active tab of front window
                end if
            end tell
            """
        }
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output = scriptObject.executeAndReturnError(&error)
            return output.stringValue
        }
        return nil
    }

    func getAllOpenUrls(browsers: [String]) -> [String] {
        var foundUrls = Set<String>()
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier, browsers.contains(bundleId) else { continue }
            let appName = app.localizedName ?? ""
            
            var scriptSource = ""
            if bundleId == "com.apple.Safari" {
                scriptSource = """
                set allUrls to ""
                tell application "Safari"
                    repeat with w in windows
                        repeat with t in tabs of w
                            set allUrls to allUrls & URL of t & "\n"
                        end repeat
                    end repeat
                end tell
                return allUrls
                """
            } else if bundleId == "company.thebrowser.Browser" {
                scriptSource = """
                set allUrls to ""
                tell application "Arc"
                    repeat with w in windows
                        repeat with t in tabs of w
                            set allUrls to allUrls & URL of t & "\n"
                        end repeat
                    end repeat
                end tell
                return allUrls
                """
            } else {
                scriptSource = """
                set allUrls to ""
                tell application "\(appName)"
                    repeat with w in windows
                        repeat with t in tabs of w
                            set allUrls to allUrls & URL of t & "\n"
                        end repeat
                    end repeat
                end tell
                return allUrls
                """
            }
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptSource) {
                let output = scriptObject.executeAndReturnError(&error)
                let urlsString = output.stringValue ?? ""
                let urls = urlsString.components(separatedBy: "\n")
                for url in urls {
                    let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !trimmed.contains("localhost:10000") {
                        foundUrls.insert(trimmed)
                    }
                }
            }
        }
        return Array(foundUrls).sorted()
    }

    private func getArcURL(pid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let window = focusedWindow {
            if let url = findURLInElement(window as! AXUIElement) {
                return url
            }
        }
        var windows: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows) == .success,
           let windowList = windows as? [AXUIElement], let firstWindow = windowList.first {
            if let url = findURLInElement(firstWindow) {
                return url
            }
        }
        return nil
    }

    private func findURLInElement(_ element: AXUIElement, depth: Int = 0) -> String? {
        if depth > 15 { return nil }
        var role: CFTypeRef?
        var title: CFTypeRef?
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        let roleStr = role as? String ?? ""
        let titleStr = title as? String ?? ""
        let valStr = (value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if roleStr == "AXTextField" || roleStr == "AXStaticText" || roleStr == "AXComboBox" {
            if !valStr.isEmpty {
                if valStr.lowercased().hasPrefix("http") { return valStr }
                if valStr.contains(".") && !valStr.contains(" ") && valStr.count > 3 {
                    return "https://" + valStr
                }
            }
        }
        if depth == 0 && (titleStr.hasPrefix("http") || (titleStr.contains(".") && !titleStr.contains(" "))) {
            return titleStr.hasPrefix("http") ? titleStr : "https://" + titleStr
        }
        var children: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success, 
           let childrenList = children as? [AXUIElement] {
            for child in childrenList {
                if let found = findURLInElement(child, depth: depth + 1) {
                    return found
                }
            }
        }
        return nil
    }
}

class BrowserMonitor {
    private var timer: Timer?
    private weak var appState: AppState?
    private let server: LocalServer?
    private let automator: BrowserAutomator
    private var lastRedirectTime: [String: Date] = [:]
    
    private let browsers = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "company.thebrowser.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi"
    ]

    init(appState: AppState, server: LocalServer? = LocalServer(), automator: BrowserAutomator = DefaultBrowserAutomator()) {
        self.appState = appState
        self.server = server
        self.automator = automator
        checkPermissions(prompt: true)
        server?.start()
        startMonitoring()
    }

    func checkPermissions(prompt: Bool = false) {
        let trusted = automator.checkPermissions(prompt: prompt)
        DispatchQueue.main.async {
            self.appState?.isTrusted = trusted
        }
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPermissions(prompt: false)
            self?.checkActiveTab()
        }
    }

    func log(_ message: String) {
        let entry = "\(Date()): \(message)\n"
        if let data = entry.data(using: .utf8) {
            let fileURL = URL(fileURLWithPath: "/tmp/free_app.log")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }

    func checkActiveTab() {
        guard let appState = appState, appState.isBlocking, !appState.isPaused else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        
        if let bundleId = frontApp.bundleIdentifier, browsers.contains(bundleId) {
            if let lastRedirect = lastRedirectTime[bundleId], Date().timeIntervalSince(lastRedirect) < 2.0 {
                return
            }
            
            if let currentURL = automator.getActiveUrl(for: frontApp) {
                log("Detected URL: \(currentURL) in \(frontApp.localizedName ?? "Unknown")")
                if currentURL.contains("localhost:10000") { return }

                if !RuleMatcher.isAllowed(currentURL, rules: appState.allowedRules) {
                    log("BLOCKED: \(currentURL)")
                    lastRedirectTime[bundleId] = Date()
                    automator.redirect(app: frontApp, to: "http://localhost:10000")
                }
            }
        }
    }

    func getAllOpenUrls() -> [String] {
        return automator.getAllOpenUrls(browsers: browsers)
    }
}
