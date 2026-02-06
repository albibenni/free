import Foundation
import AppKit
import ApplicationServices

class BrowserMonitor {
    private var timer: Timer?
    private weak var appState: AppState?
    private let server = LocalServer()
    
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

    init(appState: AppState) {
        self.appState = appState
        
        // Check permissions immediately (prompt only on first launch)
        checkPermissions(prompt: true)
        
        // Start local blocking server
        server.start()
        
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
        
        // Arc Special Handling: Check for Little Arc (blind window)
        // If it's Arc, we let getActiveUrl try to find the URL.
        
        // Log non-browser apps only occasionally to avoid spam, but for now log everything relevant
        if let bundleId = frontApp.bundleIdentifier, browsers.contains(bundleId) {
            // Get the URL
            if let currentURL = getActiveUrl(for: frontApp) {
                log("Detected URL: \(currentURL) in \(frontApp.localizedName ?? "Unknown")")
                
                // Check if we are already on our block page to avoid loops
                if currentURL.contains("localhost:10000") {
                    return
                }

                if !isAllowed(currentURL, rules: appState.allowedRules) {
                    log("BLOCKED: \(currentURL) -> Action Taken")
                    if bundleId == "company.thebrowser.Browser" {
                        // For Arc, try redirect first. If it's Little Arc, it will likely fail.
                        redirectTab(app: frontApp, to: "http://localhost:10000")
                        // Immediately attempt AX force close as well for Little Arc
                        closeArcWindow(pid: frontApp.processIdentifier)
                    } else {
                        redirectTab(app: frontApp, to: "http://localhost:10000")
                    }
                } else {
                    log("ALLOWED: \(currentURL)")
                }
            } else {
                log("Could not get URL from \(frontApp.localizedName ?? "Unknown")")
                
                // Arc Specific Fallback:
                if bundleId == "company.thebrowser.Browser" {
                    log("Arc window detected but URL unreadable. Force closing via AX.")
                    closeArcWindow(pid: frontApp.processIdentifier)
                }
            }
        }
    }
    
    func isAllowed(_ url: String, rules: [String]) -> Bool {
        for rule in rules {
            if rule.contains("*") {
                // Wildcard match (Case & Diacritic Insensitive)
                let predicate = NSPredicate(format: "SELF LIKE[cd] %@", rule)
                if predicate.evaluate(with: url) {
                    return true
                }
            } else {
                // Standard containment match
                if url.localizedCaseInsensitiveContains(rule) {
                    return true
                }
            }
        }
        return false
    }

    func redirectTab(app: NSRunningApplication, to url: String) {
        let scriptSource: String
        let appName = app.localizedName ?? "Safari"
        
        if app.bundleIdentifier == "company.thebrowser.Browser" {
             scriptSource = """
            tell application "Arc"
                if (count of windows) > 0 then
                    try
                        set URL of active tab of front window to "\(url)"
                    on error
                        try
                            set URL of window 1 to "\(url)"
                        end try
                    end try
                end if
            end tell
            """
        } else if app.bundleIdentifier == "com.apple.Safari" {
             scriptSource = """
            tell application "Safari"
                if (count of windows) > 0 then
                    set URL of current tab of front window to "\(url)"
                end if
            end tell
            """
        } else {
            // Chromium based browsers (Chrome, Brave, Edge, Arc, Opera, Vivaldi) usually share the same AppleScript suite
            // We just need to target the correct application name.
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
        // Arc Special Handling using Accessibility API (More robust for Little Arc)
        if app.bundleIdentifier == "company.thebrowser.Browser" {
            if let url = getArcURL(pid: app.processIdentifier) {
                return url
            }
            // Fallback to standard AppleScript if AX fails (unlikely)
        }

        var scriptSource = ""
        let appName = app.localizedName ?? "Safari"
        
        if app.bundleIdentifier == "com.apple.Safari" {
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
            if let url = output.stringValue {
                return url
            }
        }
        
        return nil
    }

    // MARK: - Accessibility API Helpers for Arc
    func closeArcWindow(pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let window = focusedWindow {
            let windowElement = window as! AXUIElement
            
            // Try to perform the close action directly on the window
            // In many Chromium apps, the close button is the most reliable target
            var closeButton: CFTypeRef?
            if AXUIElementCopyAttributeValue(windowElement, kAXCloseButtonAttribute as CFString, &closeButton) == .success {
                AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
                log("Force closed Arc window via AX Close Button")
            } else {
                // Fallback: Try AXCancelAction on the window element
                AXUIElementPerformAction(windowElement, kAXCancelAction as CFString)
                log("Force closed Arc window via AX Cancel Action")
            }
        }
    }

    func getArcURL(pid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(pid)
        
        // 1. Try Focused Window first (fastest)
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let window = focusedWindow {
            if let url = findURLInElement(window as! AXUIElement) {
                return url
            }
        }
        
        // 2. Fallback: Iterate all windows (Little Arc might not be "focused" in AX terms but is visible)
        var windows: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows) == .success,
           let windowList = windows as? [AXUIElement] {
            for window in windowList {
                if let url = findURLInElement(window) {
                    return url
                }
            }
        }
        
        return nil
    }

    func findURLInElement(_ element: AXUIElement, depth: Int = 0) -> String? {
        if depth > 15 { return nil }
        
        // Check Role & Description
        var role: CFTypeRef?
        var description: CFTypeRef?
        var title: CFTypeRef?
        var value: CFTypeRef?
        
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        let roleStr = role as? String ?? ""
        let descStr = (description as? String ?? "").lowercased()
        let titleStr = title as? String ?? ""
        let valStr = value as? String ?? ""

        // 1. Check if this is likely an address bar (TextField) or Little Arc display (StaticText)
        if roleStr == "AXTextField" || roleStr == "AXStaticText" || roleStr == "AXComboBox" {
            if !valStr.isEmpty {
                // Case A: Full URL (http/https) - Common in Main Window TextFields
                if valStr.hasPrefix("http") {
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


