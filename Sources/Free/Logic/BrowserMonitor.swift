import Foundation
import AppKit
import ApplicationServices

class BrowserMonitor {
    private var timer: Timer?
    private weak var appState: AppState?
    private let server: LocalServer?
    private var lastRedirectTime: [String: Date] = [:]
    
    // Supported browsers bundle IDs
    private let browsers = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "company.thebrowser.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi"
    ]

    init(appState: AppState, server: LocalServer? = LocalServer()) {
        self.appState = appState
        self.server = server
        
        // Check permissions immediately (prompt only on first launch)
        checkPermissions(prompt: true)
        
        // Start local blocking server
        server?.start()
        
        startMonitoring()
    }

    func checkPermissions(prompt: Bool = false) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async {
            self.appState?.isTrusted = trusted
        }
        if !trusted && prompt {
            print("WARNING: Accessibility permissions not granted. Blocking will not work.")
        }
    }

    func startMonitoring() {
        // Check every 1 second
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

        // Get the frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        
        // Log non-browser apps only occasionally to avoid spam, but for now log everything relevant
        if let bundleId = frontApp.bundleIdentifier, browsers.contains(bundleId) {
            
            // Cooldown check to prevent spamming redirects/UI scripting
            if let lastRedirect = lastRedirectTime[bundleId], Date().timeIntervalSince(lastRedirect) < 2.0 {
                return
            }
            
            // Get the URL
            if let currentURL = getActiveUrl(for: frontApp) {
                log("Detected URL: \(currentURL) in \(frontApp.localizedName ?? "Unknown")")
                
                // CRITICAL: Avoid blocking our own block page
                if currentURL.contains("localhost:10000") {
                    return
                }

                if !RuleMatcher.isAllowed(currentURL, rules: appState.allowedRules) {
                    log("BLOCKED: \(currentURL) (Current Rules: \(appState.allowedRules.joined(separator: ", ")))")
                    lastRedirectTime[bundleId] = Date()
                    redirectTab(app: frontApp, to: "http://localhost:10000")
                } else {
                    // log("ALLOWED: \(currentURL)")
                }
            } else {
                log("Could not get URL from \(frontApp.localizedName ?? "Unknown")")
            }
        }
    }
    
    func redirectTab(app: NSRunningApplication, to url: String) {
        let scriptSource: String
        let appName = app.localizedName ?? "Safari"
        let bundleId = app.bundleIdentifier ?? ""
        
        if bundleId == "company.thebrowser.Browser" {
            // Arc specific: Try to redirect without closing windows
            scriptSource = """
            tell application "Arc"
                activate
                if (count of windows) > 0 then
                    try
                        -- Method 1: Standard redirect
                        set URL of active tab of front window to "\(url)"
                    on error
                        -- Method 2: UI scripting for Little Arc (redirect in-place)
                        try
                            tell application "System Events"
                                tell process "Arc"
                                    -- Focus address bar (Cmd+L)
                                    keystroke "l" using {command down}
                                    delay 0.1
                                    -- Type URL
                                    keystroke "\(url)"
                                    -- Press Enter (key code 36)
                                    key code 36
                                end tell
                            end tell
                        on error
                            -- Fallback: do nothing to avoid new tab spam
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
            // Chromium based browsers usually share the same AppleScript suite
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
        
        // Arc Special Handling: AppleScript gives the FULL URL (path + query), AX is for Little Arc fallback
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
            
            // Fallback to AX for Little Arc (usually just the domain)
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

    func getAllOpenUrls() -> [String] {
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
                // Arc handles tabs differently but this usually works for standard tabs
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
                // Standard Chromium
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

    // MARK: - Accessibility API Helpers for Arc
    func getArcURL(pid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(pid)
        
        // 1. Try Focused Window first (fastest and most accurate for redirecting)
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let window = focusedWindow {
            if let url = findURLInElement(window as! AXUIElement) {
                return url
            }
        }
        
        // 2. Fallback: Check ONLY the frontmost window in the window list (avoids background window loops)
        var windows: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows) == .success,
           let windowList = windows as? [AXUIElement], let firstWindow = windowList.first {
            if let url = findURLInElement(firstWindow) {
                return url
            }
        }
        
        return nil
    }

    func findURLInElement(_ element: AXUIElement, depth: Int = 0) -> String? {
        if depth > 15 { return nil }
        
        // Check Role & Description
        var role: CFTypeRef?
        var title: CFTypeRef?
        var value: CFTypeRef?
        
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        let roleStr = role as? String ?? ""
        let titleStr = title as? String ?? ""
        let valStr = (value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Check if this is likely an address bar (TextField) or Little Arc display (StaticText)
        if roleStr == "AXTextField" || roleStr == "AXStaticText" || roleStr == "AXComboBox" {
            if !valStr.isEmpty {
                // Case A: Full URL (http/https) - Common in Main Window TextFields
                if valStr.lowercased().hasPrefix("http") {
                    return valStr
                }
                
                // Case B: Raw Domain (e.g. "youtube.com") - Common in Little Arc StaticText
                // Heuristic: Contains dot, no spaces, reasonable length
                if valStr.contains(".") && !valStr.contains(" ") && valStr.count > 3 {
                    return "https://" + valStr
                }
            }
        }
        
        // 2. Check window title as fallback (sometimes Little Arc shows URL in title)
        if depth == 0 && (titleStr.hasPrefix("http") || (titleStr.contains(".") && !titleStr.contains(" "))) {
            return titleStr.hasPrefix("http") ? titleStr : "https://" + titleStr
        }
        
        // 3. Recurse Children
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